---
title: "Node.js OOM 与容器内存排查"
urlSlug: 'nodejs-oom-container-memory-budget'
published: 2026-09-28
description: '从一次 Node.js 内存耗尽排查，记录查询投影、按需读取和恢复并发的调整，以及 V8 老生代、进程 RSS 与 Kubernetes 内存预算的区别。'
image: ''
author: ""
tags: ['Node.js', 'Kubernetes', 'GitOps', '内存', '故障排查', '实战记录']
category: '云原生与容器'
draft: false
lang: 'zh_CN'
---

一个运行在 Kubernetes 中的 Node.js 任务服务出现了内存耗尽。修复同时涉及应用和部署配置：应用收紧查询投影，改为按需读取，并调整恢复路径的并发；GitOps 中则固化对应的内存预算。服务随后恢复就绪。

这篇根据 9 月 28 日的排障记录整理，项目与示例已匿名化。重点记录数据如何进入进程内存，以及怎样把 V8 堆限制和容器资源放在一起判断。

## 先分清进程为什么退出

遇到重启，先保留上一轮容器的状态和日志。只看当前 `Running`，会错过已经退出的实例；只看退出码，也容易把不同原因混在一起。

下面是只读排查命令示例，命名空间、Pod 和容器名使用占位符：

```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> -c <container> --previous
kubectl top pod <pod> -n <namespace> --containers
```

第一条用于查看上一轮终止原因、重启计数和事件；第二条查看前一个容器实例的应用日志。`kubectl top` 依赖集群指标组件，看到的是当前采样，未必包含退出前的峰值。

V8 在堆分配失败时可能自行报告 JavaScript 堆内存耗尽；容器也可能因内存压力被内核终止，两者需要分别找证据。退出码 `137` 常对应被 `SIGKILL` 终止，也可能来自人工操作或其他终止路径，不能单凭它认定 OOM。应继续核对 `OOMKilled`、应用错误和节点侧记录，必要时结合 cgroup 事件。[Kubernetes 容器资源与内存限制](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

这个区分会影响修复方向：V8 堆达到上限时，进程可能还有容器内存余量；容器达到限制时，单纯扩大 V8 堆可能让它更早被终止。

## 查询结果有多大，比接口返回有多大更早发生

这次应用修复把查询投影和按需读取作为重点。任务列表、恢复扫描通常只需要标识、状态和少量调度字段。如果为了筛选这些字段，先读取并解析整个状态对象，再在 JavaScript 中裁剪，最终接口即使只返回几行，前面的分配成本也已经发生。

较大的 JSON 状态经过驱动取回、解析和对象处理时，可能同时存在文本、对象和复制出来的工作数据。数据库里的字段字节数不能直接当成 Node.js 堆占用；投影结果变小，也不能直接换算成内存下降比例。

因此，读取路径需要围绕调用者整理：列表读列表字段，详情请求再取详情，恢复流程只取本轮需要处理的对象。下面用简化伪代码说明读取顺序：

```ts
const summaries = await repository.listRecoveryCandidates({ limit: recoveryBatchSize });

await forEachWithLimit(summaries, recoveryConcurrency, async (summary) => {
  const state = await repository.readRecoveryState(summary.id);
  await resumeTask(state);
});
```

批量大小和并发数由配置给出。示例中的 `forEachWithLimit` 是限制恢复并发的辅助函数，需要自行实现。生产路径还要处理任务所有权、重试与幂等。

缩小投影的目的，是减少传到应用并由应用处理的数据。如果投影是在数据库中提取 JSON 字段，还需要单独看执行计划和数据库开销，不能仅凭网络返回变小，就宣称数据库已经不再扫描大对象。

## 恢复路径也会形成内存峰值

重启以后，服务会重新检查尚未结束的任务。这个过程本身可能密集读取状态、构造上下文并等待外部结果。单条路径看起来可控，多个恢复操作同时展开时，内存占用却会叠加。

粗略估算时，可以把“同时存活的任务上下文数量”和“每个上下文的占用”放在一起看，再加上进程基础开销。这只是帮助定位的估算，实际值还受共享对象、缓冲区和垃圾回收时机影响。

所以并发需要覆盖到恢复路径，不能只限制新任务执行，却让启动时的恢复全部同时进行。这次修复调整了这部分并发；它和按需读取配合，分别约束单次需要的数据和同时保留的数据量。

调低并发也有代价：恢复可能变慢，积压任务会等待更久。验证时应观察恢复耗时、积压变化和正常请求延迟，而不是只看进程没有再次退出。

## 把 V8、RSS 和容器预算分开记

`--max-old-space-size` 控制的是 V8 老生代的最大内存，单位为 MiB。它不限制整个进程的 RSS，也不是 Kubernetes 的容器总内存上限。接近该限制时，V8 会花更多时间尝试垃圾回收。[Node.js 命令行参数文档](https://nodejs.org/api/cli.html#--max-old-space-sizesize-in-mib)

进程里还有年轻代、原生对象、代码和缓冲区等占用。排查时可以记录以下指标，示例只输出内存统计，不输出任务内容：

```js
const { rss, heapUsed, heapTotal, external, arrayBuffers } = process.memoryUsage();
console.log({ rss, heapUsed, heapTotal, external, arrayBuffers });
```

`heapUsed` 和 `heapTotal` 描述 V8 堆；RSS 覆盖进程驻留内存。`arrayBuffers` 已包含在 `external` 中，不能再把两者相加当成额外总量；RSS 和这些字段也不是互不重叠的账目。[Node.js 内存统计文档](https://nodejs.org/api/process.html#processmemoryusage)

Kubernetes 的 `requests.memory` 主要参与调度，`limits.memory` 则约束容器。给老生代留出的预算需要在容器限制之内，并为其他进程内存和容器开销留出余量；节点还要容纳其他工作负载。这里没有一个适用于所有服务的固定比例，实际应结合峰值和部署环境测量。

这次把内存预算写进 GitOps，是为了让源码和目标部署状态一起留下可审查的变更。应用的默认值、部署中的环境变量和实际生效参数也要逐一对应，避免排查的是一套限制，进程运行的是另一套限制。

## 恢复以后还要观察什么

当时的结果是部署版本恢复就绪，并连续完成了 60 次 readiness 检查。这是短时恢复证据，说明健康检查路径在观察期间可用；它不能证明业务高峰、较大状态量和重启恢复同时发生时也有足够余量。

后续验收应保留内存随时间的曲线，至少覆盖空闲、业务执行和积压恢复。应用侧关注堆、RSS 与缓冲区，容器侧关注内存与终止事件，再把它们与恢复并发、查询范围和处理耗时对照。只有同一工作负载下的前后数据，才能判断具体是哪项调整降低了峰值，以及是否付出了可接受的吞吐代价。

如果再出现内存持续增长，还需要进一步检查对象生命周期和分配路径。这次已经完成的读取与并发调整，不足以单独证明所有内存增长都已解释清楚；保留这些观测，下一次排查才能从具体变化继续往下走。
