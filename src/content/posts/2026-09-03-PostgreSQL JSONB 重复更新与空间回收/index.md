---
title: "PostgreSQL JSONB 重复更新与空间回收"
urlSlug: 'postgresql-jsonb-write-amplification-recovery'
published: 2026-09-03
description: '记录一次 PostgreSQL JSONB 等值更新导致的空间膨胀排查：用条件更新停止空闲写入，再在维护窗口回收空间，并核对状态、TOAST 与 WAL。'
image: ''
author: ""
tags: ['PostgreSQL', 'JSONB', '数据库', '故障排查', '实战记录']
category: 'DevOps 自动化与工程实践'
draft: false
lang: 'zh_CN'
---

一个内部任务服务的 PostgreSQL 数据库占用了约 142.54 GB，但主要状态字段的存储大小只有约 2.53 MB。任务已经空闲，状态行仍在被反复更新。排查最终落到一处事务收尾逻辑：即使没有领取到任务、状态没有变化，也会把完整 JSONB 再写回数据库。

修复后先确认空闲写入停止，再安排数据库维护，数据库体积降到了约 31.67 MB。本文根据 9 月 3 日的排障记录整理，项目与示例已匿名化。

## 从表体积找到重复更新

这个服务使用 PostgreSQL 18，把任务、事件等运行状态放在一个 JSONB 字段中。Worker 领取任务时，先锁住状态行，读取并处理状态，最后写回。这样的结构便于维持事务一致性，但也让所有调用共用一条写入路径。

最初值得核对的是三个不同的大小：整个数据库、状态表连同索引和 TOAST 的总大小，以及当前 JSONB 字段的存储大小。以下为只读观测 SQL 的简化示例，表名和字段名已泛化；实际使用时应替换为待排查对象：

```sql
SELECT
  pg_database_size(current_database()) AS database_bytes,
  pg_total_relation_size('public.state_store') AS table_total_bytes;

SELECT pg_column_size(payload) AS json_stored_bytes, updated_at
FROM public.state_store
WHERE id = 1;

SELECT n_tup_upd, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'state_store';
```

`pg_total_relation_size` 统计的是表的整体物理占用，不能把它当成当前 JSON 文档的大小。TOAST 用于存放较大的字段值。[PostgreSQL TOAST 文档](https://www.postgresql.org/docs/current/storage-toast.html) 这次的大部分占用集中在相关 TOAST 对象中。与此同时，Worker 没有业务任务可领，状态行的 `updated_at` 却仍然前进，更新计数也在增加。这把调查范围缩小到了空闲轮询的事务路径。

代码中的顺序是：读取状态、调用操作函数、无条件执行 `UPDATE`。领取操作返回“没有任务”，并不会跳过最后一步。于是空闲调用也被转换成了写事务。

PostgreSQL 不会因为新值看起来和旧值相同，就自动替应用省掉所有更新工作。官方文档专门提供了抑制冗余更新的触发器，并说明无变化更新仍可能付出时间与旧行版本清理的代价。[PostgreSQL 冗余更新说明](https://www.postgresql.org/docs/15/functions-trigger.html)

这次重复更新造成了实际的 TOAST 膨胀。某次更新是否复用 TOAST 值、触及哪些索引，取决于写入方式与执行路径；相同值 UPDATE 并不必然重写全部 TOAST 和全部索引。

## 在写入位置判断状态是否变化

修复保留原有事务和行锁，只改变写回条件。下面用一次性临时表演示条件更新，参数由调用方绑定：

```sql
UPDATE pg_temp.state_demo
SET schema_version = $1,
    payload = $2::jsonb,
    updated_at = NOW()
WHERE id = 1
  AND (
    schema_version IS DISTINCT FROM $1
    OR payload IS DISTINCT FROM $2::jsonb
  );
```

版本或状态内容有变化时照常写入；两者都没有变化时，更新条件不成立。`IS DISTINCT FROM` 是空值安全比较：两边都是 `NULL` 时视为没有差异，只有一边是 `NULL` 时视为有差异，避免普通 `<>` 的未知结果影响判断。[PostgreSQL 比较谓词](https://www.postgresql.org/docs/current/functions-comparison.html)

验证也需要覆盖两条分支。当时增加的 PostgreSQL 集成检查，先固定状态行的更新时间，执行一次空操作，确认时间没有变化；再执行一个确实改变状态的操作，确认新状态落库、更新时间改变。只有前一条检查，会漏掉“所有更新都被挡住”的错误。

这个补丁解决了无变化事务的写入。原有单行锁仍然存在，完整状态的读取和处理也仍有成本；它没有完成任务存储的规范化迁移，也没有证明可以无限增加 Worker。

## 停止增长以后再回收空间

代码修复上线后，旧的膨胀空间不会随之自动消失。首先做了一次 60 秒空闲采样：状态更新时间、行更新计数、TOAST 插入计数和 WAL 字节计数都没有增加。确认写入停止后，才进入空间回收步骤。

普通 `VACUUM` 主要清理旧版本并让空间可复用，通常不会把所有空闲空间归还操作系统；尾部空页截断是例外，也可能需要额外锁。`VACUUM FULL` 则重写表，能回收更多物理空间，同时需要额外磁盘空间和 `ACCESS EXCLUSIVE` 锁，会阻塞该表的其他访问。[PostgreSQL VACUUM 文档](https://www.postgresql.org/docs/current/sql-vacuum.html)

因此这次维护放在确认业务任务均已结束的窗口中。维护前生成了 custom-format 备份，用 `pg_restore --list` 检查备份目录可读取，并保存校验值。这个检查能确认归档目录可解析，不能替代把备份完整恢复到独立数据库的演练。真正依赖它回退前，还要考虑恢复耗时、维护后新写入的数据，以及可用的恢复环境。

维护开始后，重写操作没有立即取得锁。检查活动会话和锁后，发现 6 个从数据库重启时遗留的 Worker 会话卡在同一条 `SELECT … FOR UPDATE` 上。再次核对任务终态、会话来源和等待关系后，才定向终止这些已确认的会话，维护随后完成。

终止会话会中断调用并回滚未提交事务；数据库里看不到待处理任务，也不足以单独证明所有外部工作都可以中断。类似操作需要结合应用状态、维护授权和恢复安排判断。

## 回收结果与验证边界

下表由当时的字节统计按十进制单位换算：

| 观测对象 | 维护前 | 维护后 |
| --- | ---: | ---: |
| 整个数据库 | 142.54 GB | 31.67 MB |
| 状态表整体占用 | 142.51 GB | 2.76 MB |
| JSONB 字段存储大小 | 2.53 MB | 2.53 MB |

JSONB 字段大小保持不变，状态表整体占用大幅下降，说明主要回收了历史物理膨胀。维护后又做了一次 60 秒空闲采样，更新、TOAST 插入和 WAL 增量仍为零；线上版本与 readiness 回读正常，工作负载最终恢复就绪。

这两次采样只说明当时的空闲窗口没有继续重复写入。重写维护本身会产生 I/O 和 WAL，正常业务修改状态也仍然需要写入。短时健康检查同样不能替代业务验收：这次没有完成独立的完整备份恢复演练，也没有把人工业务操作验证纳入这轮结果。

后续观察要继续保留“当前字段大小”和“表整体大小”两个维度，并把更新计数与真实任务活动对照。空闲时状态行仍然频繁更新，就有必要重新检查调用路径；业务繁忙时则要观察写入速率、表增长和清理是否跟得上。
