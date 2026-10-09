---
title: "PostgreSQL 与 FFmpeg 测试提速"
urlSlug: 'postgresql-ffmpeg-test-runtime'
published: 2026-10-08
description: '从测试身份准备缓存讨论 PostgreSQL 回归的隔离边界，并结合既有 FFmpeg 线程约束说明并发、环境开销和性能测量应如何分开。'
image: ''
author: ""
tags: ['PostgreSQL', 'FFmpeg', 'Node.js', '测试', '性能优化', '实战记录']
category: 'DevOps 自动化与工程实践'
draft: false
lang: 'zh_CN'
---

数据库和媒体测试耗时，不能只看断言所在的几行代码。创建测试环境、准备身份、建立连接、启动子进程和转换媒体，都可能占用时间。要减少等待，先得把可重复使用的准备工作与每个用例必须独立的状态分开。

本文根据 2026 年 10 月 8 日的测试优化记录事后整理，项目信息已匿名化。当天新增了身份准备缓存，每个测试仍使用独立 PostgreSQL Schema、执行完整迁移，并创建新的会话凭据。FFmpeg 的线程约束在项目早期就已存在。

## 缓存身份准备，保留数据库初始化

数据库测试常把多项工作装进一个 fixture：创建 Schema、执行迁移、准备用户、创建会话，最后返回应用实例。fixture 重复执行，里面每一项也跟着重复，很容易让人产生“直接复用整套环境”的想法。

但复用边界差一点，测试含义就变了。前一个用例改过用户权限，后一个用例可能读到它的结果；会话被撤销后，另一个用例继续拿同一份凭据请求接口；某次迁移只在首个用例运行，后面的用例实际上一直依赖已经建好的数据库。

当时的 `cached-identity-fixture` 将缓存范围限制在身份准备这一层。它没有把可变数据库、已迁移 Schema 或会话一起变成共享实例。每个测试仍然独立建立数据库对象并执行完整迁移，再使用准备好的身份材料创建自己的测试身份与新会话。

这个划分保留了数据库测试原本要验证的路径。迁移是否能从规定起点完成，约束是否正确建立，以及数据库初始化后应用能否实际读取，都仍然经过真实 PostgreSQL。缓存减少的是重复准备，不会用一个已初始化模板替代这些操作。

下面用简化伪代码演示 fixture 生命周期，清理仅针对本次测试创建的一次性 Schema：

```js
const identityTemplate = await getPreparedIdentity(); // 可复用的准备材料
const fixture = await createIsolatedPostgresFixture(); // 专用测试库的新 Schema

try {
  await fixture.runAllMigrations();
  await fixture.seedIdentity(structuredClone(identityTemplate));
  const session = await fixture.createNewSession();
  await runScenario({ database: fixture.database, session });
} finally {
  await fixture.closeAllConnections();
  await fixture.dropOwnedSchema();
}
```

示意里的副本强调了另一个要求：缓存材料如果包含可变对象，交给用例前还要隔离它的修改。数据库独立，并不自动使 JavaScript 中共享的对象也独立。

## 独立 Schema 也要核对连接路径

随机 Schema 可以让多个 fixture 在同一个测试数据库中建立同名表，但连接必须始终指向自己的对象。使用连接池时，不能只在一条连接上设置路径，然后假定所有连接都相同。

排查这一层时，可以在实际执行测试 SQL 的连接上做只读确认：

```sql
SELECT current_database(), current_schema();
SHOW search_path;
```

未限定名称的对象会按照 `search_path` 查找，第一项匹配的对象会被使用；默认创建位置也受路径影响。具体规则见 [PostgreSQL Schema 文档](https://www.postgresql.org/docs/current/ddl-schemas.html)。因此，测试辅助层需要把 Schema 与连接初始化一起管理，避免某条查询意外落到 `public` 或另一个 fixture。

Schema 隔离也不等于整台数据库服务器隔离。连接数、CPU、内存和服务端配置仍然共享。它适合隔离测试对象与数据；涉及数据库级配置或整个实例的故障注入，需要另设隔离环境。

清理同样属于 fixture 的职责。先等待连接和后台操作结束，再删除自己创建的 Schema。失败时保留有界、脱敏的诊断信息，不要为了让下一项继续运行就忽略初始化错误。

## FFmpeg 的并行不能只看测试文件数量

媒体测试的资源问题在另一层。Node 的测试调度器可以同时运行多个文件，每个文件又可能启动 FFmpeg；FFmpeg 内部还有解码、滤镜和编码线程。只调测试文件并发，很容易漏掉子进程内部的并行。

[Node.js 测试运行模型](https://nodejs.org/api/test.html#test-runner-execution-model)说明，启用进程级隔离时，匹配的测试文件在子进程中运行，`--test-concurrency` 控制同时运行的文件进程数。它不会自动限制文件启动的外部程序。

项目早期测试文档已经要求媒体测试执行真实 FFmpeg，并通过测试专用入口约束解码、滤镜和编码线程。对于简单滤镜，FFmpeg 有 `-filter_threads`；复杂滤镜另有 `-filter_complex_threads`。两者的默认线程数量都与可用 CPU 有关，见 [FFmpeg 参数文档](https://ffmpeg.org/ffmpeg.html)。编码线程还需要按所选编码器处理，参数位置也要区分输入和输出。

限制内部线程，目的是让多个小型媒体测试的资源消耗更可控。它不保证所有机器上都会更快，也不能推广成生产转码应当单线程。生产任务可能追求一段大视频的吞吐，测试套件则需要在多个任务之间分配资源，两种场景要分别测量。

真实编码也应留下来。媒体测试如果改成直接返回一个预置文件，套件可能变快，却无法发现编码参数、滤镜、封装和运行环境的回归。可以讨论如何降低环境准备开销，但被测试的那次转换仍然需要执行。

## 性能结论需要同一组测量

目前缺少同一 Runner、同类负载和相同测试集合下的前后工件，尚无法量化这次缓存改动的提速幅度。

如果继续测量，需要将环境启动、身份准备、迁移、测试执行和清理分别计时，再记录整轮墙钟时间。比较时同时保留测试文件列表、通过与失败数量、并发设置、数据库版本、FFmpeg 构建和 Runner 资源，确认缩短时间没有来自少执行测试或换了机器。

首次运行和后续运行也应分开。缓存命中后的单次结果不能代表冷启动；多个文件的耗时之和也不能当成整轮等待时间。对于修改过 fixture 的套件，还应检查用例换顺序、并发执行或前一项失败时，后一项能否保持独立。

身份准备可以复用，每个用例的数据库与会话仍需要自己的生命周期。先写清这个边界，后续再对照准备耗时和整轮报告判断收益，才知道减少的等待来自哪里。
