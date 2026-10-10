# AGENTS.md — YangYuS8/blog

本文件面向在本仓库写文章、改代码和审查变更的 agent。这里是 **杨与S8的博客** 的真实内容源，不是待初始化的 Fuwari 模板。站点：<https://blog.yangyus8.top/>；默认使用简体中文。

## 适用范围与开始方式

- 本文件是仓库级约定。处理子目录前检查是否有更具体的 `AGENTS.md` / `AGENTS.override.md`，不要假定从根目录启动就会自动加载所有子目录规则。
- Codex 在启动时从项目根目录向当前工作目录发现指令；同一目录优先使用 `AGENTS.override.md`，更深层指导可覆盖上层对应规则。修改指令后用新会话验证加载。依据：[OpenAI AGENTS.md 官方指南](https://developers.openai.com/codex/guides/agents-md/)。
- 先运行 `git status --short`、`git diff`、`git diff --cached`，保留用户已有修改。围绕本次目标做小范围改动，不顺手升级依赖、批量格式化或重写旧文章。
- 按任务读取下面的事实来源。README、`.hermes.md` 和 `docs/` 可提供背景，但旧示例不能替代当前脚本、schema 和部署配置；发现冲突时说明，不扩大本次修改范围。

## 仓库地图

- `package.json`、`pnpm-lock.yaml`：命令、依赖与锁定版本；Astro 5、Svelte 5、Tailwind 3，基于 Fuwari 定制
- `src/content/posts/<YYYY-MM-DD-短标题>/index.md`：正式文章及同目录资源；`src/content/config.ts`：内容 schema
- `scripts/new-post.js`：文章生成器；`src/content/spec/about.md`：关于页内容
- `src/config.ts`：站点、作者、导航、Giscus、备案和版权配置；`astro.config.mjs`：域名、基础路径、Markdown 插件和集成
- `src/pages/`、`src/layouts/`、`src/components/`、`src/styles/`：路由、布局、组件与样式；`src/i18n/`：界面文案
- `src/utils/content-utils.ts`、`src/utils/post-slug-utils.ts`：公开 slug、草稿过滤、排序及上下篇链接
- `src/pages/posts/[...slug].astro`、`src/pages/rss.xml.ts`：文章页面、canonical / JSON-LD 和 RSS
- `.github/workflows/deploy.yml`：生产部署；`.github/workflows/blog-post-workflow.yml`：README 最新文章同步
- `docs/posts/` 是模板语法示例，不是正式发文目录；`.trash/`、`.playwright-cli/` 中的历史文件不是当前运行结果

## 环境与命令

在仓库根目录运行。优先与 CI 对齐使用 Node.js 22；pnpm 版本按 `package.json#packageManager`（当前 `pnpm@9.14.4`），不要改用 npm / yarn / bun 或新建其他锁文件。

```bash
pnpm install --frozen-lockfile
pnpm dev
pnpm check
pnpm exec biome check ./src
pnpm build
pnpm preview
```

- `pnpm dev` / `pnpm start` 启动开发服务，默认 `http://localhost:4321`。
- `pnpm check` 执行 `astro check`；`pnpm exec biome check <相关文件或目录>` 是不自动改写文件的检查，可先缩小范围。
- **`pnpm lint` 会执行 `biome check --write ./src`，`pnpm format` 也会改写文件。** 不要把它们当成只读检查；确需修复格式时限定文件并审阅 diff。
- `pnpm build` 执行 `astro build && pagefind --site dist`，包含搜索索引生成。搜索在 dev 中使用假数据，必须 build 后用 preview 验证。
- `pnpm type-check` 是额外的 `tsc --noEmit --isolatedDeclarations` 检查，不等同于 Astro 检查。当前没有 `test` 脚本或独立自动化测试套件，不要声称运行了 `pnpm test`。
- 安装失败先报告原因；不要为绕过 frozen lockfile 错误而擅自重写锁文件。只有依赖变更任务才同步修改 manifest 与锁文件。

## 新建与编辑文章

优先使用生成器，中文标题显式提供有含义的英文 kebab-case slug：

```bash
pnpm new-post "k3s 部署 Loki 与 Grafana Alloy" --slug k3s-loki-grafana-log-query-guide
pnpm new-post "文章标题" --slug meaningful-english-slug --author "作者名"
```

- 生成器创建 `YYYY-MM-DD-标题/index.md`，清理目录非法字符，并为重复目录、重复 slug 添加数字后缀。日期取运行环境的本地日期，发文前核对是否符合本次需求。
- 生成器只提取 ASCII 字母和数字，**不会翻译中文**；纯中文标题不传 `--slug` 会失败，混合标题也需检查生成结果是否有意义。
- 新文章目录应与当前标题对应；修改旧文章标题时如需同步重命名目录，检查相对资源和内部引用，但保持 `urlSlug` 不变。
- 不创建日期序号式或无意义 slug，如 `20260421-02`、`post-1`。README 中仍有旧日期 slug 示例，不要沿用。
- 生成器默认 `draft: false`。用户要求草稿时改为 `true`；未经核实的占位内容不得作为完成稿发布。生产构建会过滤草稿，开发模式会显示草稿。

### Frontmatter

以下是写作约定，不代表所有字段在 schema 中都必填；schema 的必填字段是 `title` 和 `published`，其他字段以 `src/content/config.ts` 为准。

```yaml
---
title: "文章标题"
urlSlug: 'meaningful-english-slug'
published: 2026-10-09
description: '一句具体、准确的内容摘要'
image: ''
author: ''
tags: ['Linux', 'Shell', '故障排查', '实战记录']
category: 'Linux 与开发环境'
draft: false
lang: 'zh_CN'
---
```

- 示例日期只是占位，使用文章实际发布日期；支持可选的 `updated` 日期，修订时不要无故改写 `published`。
- `author: ''` 回退到站主名字；客座或 agent 以自己的身份署名写作时显式填写作者，保留既有署名。
- `description` 写实际摘要；`tags` 为字符串数组，`category` 使用一个分类，`draft` 为布尔值。
- 语言字段是 **`lang`**；`frontmatter.json` 的旧 `language` 字段不能替代它。不要手填内部计算字段 `prevTitle`、`prevSlug`、`nextTitle`、`nextSlug`。
- 封面可用同目录相对路径（如 `./cover.png`）、`public/` 下的根路径（如 `/cover.png`）或完整 URL。新增/移动图片后检查大小写、路径及实际渲染。
- 不添加未经 schema 支持的业务字段；需要新字段时一并设计 schema 与消费逻辑。

### 分类与标签

正常文章从以下分类中选一个，保持字面一致：

- `建站与内容系统`：Astro / Fuwari、博客、内容与 SEO
- `Linux 与开发环境`：系统、Shell、编辑器与运行环境
- `云原生与容器`：Docker / Compose、Kubernetes / k3s / kind、Helm
- `监控与日志`：Prometheus、Grafana、Loki、EFK / ELK、Zabbix
- `网络与代理`：DNS、代理、Tailscale / Headscale、VPN 和路由
- `AI Agent 工作流`：OpenCode / OpenClaw / Hermes、skills、MCP / ACP
- `DevOps 自动化与工程实践`：Ansible / Terraform、systemd、SSH / Git、工程与面试练习

不新增 `软件教程`、`问题排查`、`编程实践`、`系统折腾`、`运维实践`、`日记` 等宽泛分类。文章优先选 4–7 个准确标签；使用官方大小写，如 `OpenCode`、`OpenClaw`、`Kubernetes`、`Docker`、`GitHub`、`Node.js`、`Shell`、`systemd`。场景标签统一用 `故障排查`、`新手教程`、`实战记录`、`日记`，不要制造同义标签。

### 写作风格

延续个人技术实践知识库风格：面向运维 / DevOps 读者，参考 `wiki.eryajf.net` 的组织方式与实用性，不复制措辞。

- 一篇文章解决一个明确目标，开头简短说明目标、环境与结论。
- 标题直接写技术和任务，尽量 8–24 个中文字符，长技术名可例外；避免“为什么我最后……”“我是怎么……”“给自己留一份……”等铺垫。
- 教程：目标 → 环境 / 准备 → 分步操作 → 验证 → 常见问题 → 总结。
- 排障：现象 → 环境 → 排查证据 → 根因 → 修复 → 验证 → 总结。
- 对比：结论 → 概念与差异 → 适用场景 → 选择建议；项目实践补充目录与踩坑记录。
- 使用直接的任务型标题、可执行命令、预期输出及验证步骤。解释必要的取舍，对初学者友好；删掉无用过渡、营销话术和空泛“最佳实践”。
- 不编造操作、日志、截图、版本或成功结果；分清亲自验证、来源记录和待验证推断。危险命令说明作用范围、前提及恢复办法，公开内容删除凭据和无关私人信息。
- Luna 署名日记保留原有声音，不强制套教程结构；frontmatter、分类与事实准确性仍需遵守。

## URL、代码与自动化边界

- 公开 URL 由 `getPostPublicSlug()` 决定：优先去除首尾空白后的非空、非日期序号 `urlSlug`，否则回退到 Astro 的 `post.slug`。文章页、列表、RSS 和上下篇链接应继续使用同一套工具函数，不另写一套 slug 推导。
- 保持已发布 `urlSlug` 和 `/posts/<slug>/` 尾斜杠稳定。Giscus 当前按 `pathname` 映射评论，变更 URL 也可能断开原评论关联。
- 只有明确要求 URL 迁移时才改 slug，并检查 canonical、RSS、站内链接、评论和旧路径兼容。`src/utils/legacy-post-slugs.ts`、`scripts/post-slug-migration.csv` 与 `vercel.json` 记录了旧迁移；**不能仅凭这些文件就认定当前生产服务器已配置重定向**，必须核验实际部署方式与 HTTP 响应。
- 遵循现有 TypeScript / Astro / Svelte 写法、`tsconfig.json` 路径别名与 `biome.json` 配置，不为小改动进行框架迁移。
- 保留 RSS 的 XML 字符清理与 HTML sanitization；涉及 Markdown 插件时同时考虑网页和 RSS 的不同渲染路径。
- 保留 README 自动区块的 `<!-- BLOG-POST-LIST:START -->` / `<!-- BLOG-POST-LIST:END -->` 标记，非本次目标不要手工改写机器人生成内容。
- 不提交 `dist/`、`.astro/`、`node_modules/`、本地日志或凭据；不修改站点身份、版权、备案与评论配置，除非任务明确涉及它们。

## 验证、提交与部署

按变更类型验证，并诚实报告未执行项：

- 仅 `AGENTS.md` / README 等非站点文档：核对路径、命令、链接和事实，检查 `git diff --check` 与最终 diff；无需只为文档安装依赖或构建站点。
- 文章 / 内容变更：核对 frontmatter、slug 唯一性、日期、作者、分类、图片和链接；运行 `pnpm check`、`pnpm build`，必要时 preview 检查文章、归档和 RSS。
- 代码 / 配置变更：先做相关文件的只读 Biome 检查，再运行 `pnpm check`、`pnpm build`；按需补充 `pnpm type-check`。UI 改动检查移动端、桌面端、深浅色及 Swup 导航后的行为；搜索用生产构建验证。
- 检查失败时区分本次引入与既有问题，不为“全绿”扩大修改范围；环境或权限阻塞时给出具体原因，不声称通过。
- 提交前检查 `git diff --check`、`git diff`、`git diff --cached`，只暂存本次文件，避免 `git add .` 混入用户改动。提交信息可用 `docs: ...`、`fix: ...`、`chore: ...`，保持范围清楚。
- 默认使用分支和可审阅的 diff / PR。**未经明确要求，不直接 push 到 `main`，不合并或手动触发生产部署。**
- 当前部署工作流在 push 到 `main` 或手动触发时，用 Node.js 22、frozen lockfile 安装并执行 `pnpm build`，随后清空服务器目标目录再上传 `dist/`。这会影响线上站点，不是只读验证；当前工作流没有 PR 触发器，也不执行 check / lint，不能把“无 CI 状态”当成检查通过。
- 交付说明改了什么、执行了哪些检查及结果、哪些未验证；涉及页面时给出预览证据。不要把本地构建成功说成已部署成功。

## Code Review Rules

- 标记未获要求的已发布 slug 变更、失效 canonical / RSS / 内部链接，以及未经真实部署验证的旧 URL 重定向承诺。
- 标记使草稿进入生产页面、归档或 RSS 的过滤回归；开发环境可见草稿是预期行为。
- 标记取消 RSS HTML 清理、引入未清理的不可信 HTML 或把凭据写入公开文章的变更。
- 标记把站点身份 / 作者错误替换为模板值、破坏 Giscus pathname 关联，以及扩大生产清理范围的变更。格式细节交给工具检查，不以个人偏好重写文章。
