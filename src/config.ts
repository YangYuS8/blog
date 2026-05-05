import type {
	ExpressiveCodeConfig,
	LicenseConfig,
	NavBarConfig,
	ProfileConfig,
	SiteConfig,
} from "./types/config";
import { LinkPreset } from "./types/config";

export const siteConfig: SiteConfig = {
	title: "杨与S8的博客",
	subtitle: "主页",
	lang: "zh_CN", // 语言代码，例如 'en'、'zh_CN'、'ja' 等
	themeColor: {
		hue: 250, // 主题色的默认色相，范围为 0 到 360。例如 red: 0、teal: 200、cyan: 250、pink: 345
		fixed: false, // 对访客隐藏主题色选择器
	},
	banner: {
		enable: true,
		src: "assets/images/月见八千代.jpeg", // 相对于 /src 目录；如果以 '/' 开头，则相对于 /public 目录
		position: "center", // 等同于 object-position，仅支持 'top'、'center'、'bottom'，默认值为 'center'
		credit: {
			enable: true, // 显示横幅图片的署名信息
			text: "月見（るなみ） ヤチヨ", // 要显示的署名文本
			url: "https://zh.moegirl.org.cn/%E6%9C%88%E8%A7%81%E5%85%AB%E5%8D%83%E4%BB%A3", // 可选：原图作品或作者页面的链接
		},
	},
	comments: {
		giscus: {
			enabled: true,
			repo: "YangYuS8/blog",
			repoId: "R_kgDORgxUDQ",
			category: "Announcements",
			categoryId: "DIC_kwDORgxUDc4C8aLr",
			mapping: "pathname",
			strict: "0",
			reactionsEnabled: "1",
			emitMetadata: "0",
			inputPosition: "top",
			lang: "zh-CN",
			loading: "lazy",
		},
	},
	toc: {
		enable: true, // 在文章右侧显示目录
		depth: 2, // 目录中显示的最大标题层级，范围为 1 到 3
	},
	filings: {
		icp: {
			enable: true,
			text: "辽ICP备2024030730号-1",
			url: "https://beian.miit.gov.cn/",
		},
		police: {
			enable: true,
			text: "川公网安备51100002000181号",
			url: "https://beian.mps.gov.cn/#/query/webSearch?code=51100002000181",
			icon: "/beian-police.png",
		},
	},
	favicon: [
		// 将此数组留空即可使用默认 favicon
		// {
		// src: '/favicon/icon.png',    // favicon 路径，相对于 /public 目录
		// theme: 'light',              // 可选：'light' 或 'dark'，仅在浅色与深色模式使用不同 favicon 时设置
		// sizes: '32x32',              // 可选：favicon 尺寸，仅在存在不同尺寸 favicon 时设置
		// }
	],
};

export const navBarConfig: NavBarConfig = {
	links: [
		LinkPreset.Home,
		LinkPreset.Archive,
		LinkPreset.About,
		{
			name: "GitHub",
			url: "https://github.com/YangYuS8", // 内部链接不应包含 base path，系统会自动补全
			external: true, // 显示外部链接图标，并在新标签页打开
		},
	],
};

export const profileConfig: ProfileConfig = {
	avatar: "assets/images/YYS8.JPG", // Relative to the /src directory. Relative to the /public directory if it starts with '/'
	name: "杨与S8",
	bio: "铅笔越削越短，人生越读越薄。",
	links: [
		{
			name: "Bilibili",
			icon: "fa6-brands:bilibili", // 图标代码可在 https://icones.js.org/ 查询
			// 如果项目中尚未包含对应图标集，你需要先安装它
			// `pnpm add @iconify-json/<icon-set-name>`
			url: "https://space.bilibili.com/435542360",
		},
		{
			name: "Steam",
			icon: "fa6-brands:steam",
			url: "https://steamcommunity.com/id/YangYuS8/",
		},
		{
			name: "GitHub",
			icon: "fa6-brands:github",
			url: "https://github.com/YangYuS8",
		},
		{
			name: "Reddit",
			icon: "fa6-brands:reddit",
			url: "https://www.reddit.com/user/YangYuS8/",
		},
		{
			name: "Linux Do",
			icon: "fa6-brands:linux",
			url: "https://linux.do/u/yangyus8/summary",
		},
	],
};

export const licenseConfig: LicenseConfig = {
	enable: true,
	name: "CC BY-NC-SA 4.0",
	url: "https://creativecommons.org/licenses/by-nc-sa/4.0/",
};

export const expressiveCodeConfig: ExpressiveCodeConfig = {
	// 注意：部分样式（例如背景色）会被覆盖，详见 astro.config.mjs 文件。
	// 请选择深色主题，因为当前博客主题只支持深色背景
	theme: "github-dark",
};
