# About

```go
package main

type Developer struct {
	Name     string
	Focus    []string
	Building []string
	Learning []string
}

func main() {
	me := Developer{
		Name: "YangYuS8",
		Focus: []string{
			"Linux desktop workflows",
			"DevOps and cloud-native practice",
			"open-source tools for real daily problems",
		},
		Building: []string{
			"LWE: Wallpaper Engine content on Linux",
			"homelab and Kubernetes experiments",
			"small AI-assisted developer tools",
		},
		Learning: []string{
			"Rust", "Go", "Kubernetes", "observability", "system design",
		},
	}

	_ = me
}
```

你好，我是杨与S8。

这个页面用来简单介绍我现在在做什么。平时我主要记录 Linux、开发环境、开源项目、部署排查、AI Agent 工作流，以及一些能复现、能验证的实践笔记。

我更喜欢从具体问题开始学习。一个工具、一个服务、一个项目，只有经历过安装、配置、报错、修复和复盘，才算真正进入自己的工具箱。

## 我在做什么

- 日常维护 Arch / CachyOS 工作站、dotfiles 和开发环境。
- 维护 LWE，一个用于在 Linux 上浏览、管理和应用 Wallpaper Engine 内容的桌面工具。
- 通过本地实验、项目和博客记录补 Kubernetes、DevOps、可观测性相关基础。
- 根据问题在 Rust、Go、TypeScript、Python、PHP、Shell 之间切换。
- 使用 AI Agents 辅助读代码、拆任务、查日志和写文档，并用本地运行、测试和部署结果复核。

## 我比较关心的东西

```yaml
Languages:
  - Rust, Go, TypeScript, Python, PHP, Shell

Frontend & Desktop:
  - Svelte, Vue, React
  - Tauri, Electron

Backend & DevOps:
  - Linux, Git, CI/CD
  - Docker / Podman, Kubernetes
  - Grafana, Loki, Alloy

Systems I care about:
  - Arch / CachyOS workstation workflows
  - PVE / self-hosted services
  - dotfiles and terminal tooling
  - Hermes / OpenClaw / skills workflows
```

## 一些项目

### LWE

LWE 是我现在投入比较多的开源项目。它是一个 Linux 桌面应用，用来浏览、管理和应用 Wallpaper Engine 内容。

这个项目覆盖了应用功能、Linux 桌面兼容性、AUR 打包、GitHub Releases、在线文档和用户反馈。每一块都能遇到真实问题，也都需要长期维护。

::github{repo="YangYuS8/lwe"}

### k8s-lab / Kube-Sentinel

我也在持续补 Kubernetes 和云原生相关内容。`k8s-lab` 主要用来放实验和笔记，`Kube-Sentinel` 用来理解 Controller、CRD、Alertmanager Webhook、Prometheus 等概念。

这部分仍然是学习和练习，不会包装成熟项目。

::github{repo="YangYuS8/k8s-lab"}

### blog / dotfiles

这个博客和 dotfiles 也算长期维护项目。

博客用来记录问题、排查过程和复盘；dotfiles 用来维护工作站配置，减少重装或迁移环境时的重复工作。它们不显眼，但很实用。

::github{repo="YangYuS8/blog"}

::github{repo="YangYuS8/dotfiles"}

## AI Agent 工作流

最近我也在持续使用和维护 AI Agent 工具链，包括 Hermes、OpenClaw、OpenCode、skills、项目规则和本地/远程 agent 协作。

这类工具的价值在于把重复的命令、排查步骤、项目约定和经验教训沉淀下来。用得好时，它可以减少重复劳动；用不好时，也会制造新的排查问题。所以我更关注可复核的流程，而不是只看生成结果。

AI 输出不能直接当作最终结论。代码、日志、测试、构建和部署结果才是最后的判断依据。

## Linux, btw

如果要说一个长期偏好，那就是 Linux。

我喜欢掌控自己的环境，理解系统行为，按自己的习惯组合工具链。很多时候，维护开发环境本身也像维护一个项目。

所以这里的很多文章会自然延伸到命令行、包管理、systemd、代理、网络、部署和故障排查。

## 关于这个博客

这个站点使用 Astro + Fuwari 构建。

这里的文章主要来自真实问题：某个包装不上、某个服务起不来、某个 DNS 行为很怪、某个 agent 工具链突然坏掉。写下来，是为了让问题以后可以被搜索、复现和修正。

如果这些记录能让未来的我少踩一次坑，或者让遇到类似问题的人更快定位方向，那就够了。
