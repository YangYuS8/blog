# About

```go
package main

type Developer struct {
	Name     string
	Role     string
	Location string
	Focus    []string
}

func main() {
	me := Developer{
		Name:     "YangYuS8",
		Role:     "Builder / Developer / Linux User",
		Location: "Earth",
		Focus:    []string{"Rust", "Kubernetes", "System Design"},
	}

	_ = me
}
```

你好，我是杨与S8。

这里不是一份标准化的简历页，更像是一块长期维护的个人工作台。我会在这里记录写代码时踩过的坑、做过的小项目、折腾过的工具链，以及一些还没完全成形、但已经值得留下痕迹的想法。

我偏爱那种能真正解决问题的东西：能跑起来，能被反复使用，最好还能在下一次重构时比上一次更干净一点。比起堆概念，我更喜欢把一个想法尽快做成可以验证的原型，再慢慢把它打磨到足够顺手。

## About Me

- 主要在做全栈方向的小项目和个人工具
- 长期关注开发体验、自动化、内容组织和可维护性
- 喜欢把想法先做成可运行的东西，再决定它值不值得继续扩展
- 对 Linux 始终有稳定兴趣，平时也乐于折腾系统和环境本身

## Tech Stack

```yaml
Frontend:
  - Vue.js
  - React
  - Next.js
  - TypeScript / JavaScript / HTML / CSS

Backend:
  - Node.js
  - Go
  - Python
  - Rust

DevOps:
  - Docker
  - Kubernetes
  - CI/CD

System:
  - Arch Linux
  - EndeavourOS
  - Ubuntu
  - Linux in general
```

## 一些项目

### WayVid

一个围绕视频处理与工作流展开的项目。对我来说，它的重点不只是“能用”，而是把流程梳理清楚，把重复劳动尽量收掉，让工具本身成为工作流的一部分。

::github{repo="YangYuS8/wayvid"}

### YoloPest

一个更偏向识别与应用落地的小项目。它吸引我的地方在于，这类东西既有模型和数据的一面，也有实际使用场景的一面，既要跑得起来，也要落得下去。

::github{repo="YangYuS8/yolopest"}

## Current Focus

- 更系统地学习 Rust，补足底层和系统编程方面的理解
- 持续摸索 Kubernetes 与 cloud-native 相关内容
- 继续建立自己对 system design 的判断，而不只是记概念
- 保持做项目、写记录、修细节这套长期节奏

## Linux, btw

如果一定要说一种长期稳定的偏好，那大概就是 Linux。

我很喜欢那种可以自己掌控环境、自己理解系统、自己决定工具链组合的感觉。很多时候，我折腾的不是“装一个能跑的系统”，而是把开发环境本身也当作项目的一部分去维护。

所以这里的很多内容，除了代码，也会自然延伸到命令行、系统配置、工作流和工程细节。

## 关于这个博客

这个站点本身也是我的项目之一。

它既用来整理技术内容，也用来保留一些阶段性的思考。很多页面、脚本和细节调整，最开始都只是为了满足我自己的使用习惯，后来才慢慢长成现在的样子。

如果你在这里看到一篇文章、一段代码，或者一个看起来有点过度设计的细节，那大概率都是我认真折腾过之后留下来的结果。