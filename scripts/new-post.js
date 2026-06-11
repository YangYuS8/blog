/* This is a script to create a new post markdown file with front-matter */

import fs from "fs";
import path from "path";

const targetDir = "./src/content/posts/";

function getDate() {
	const today = new Date();
	const year = today.getFullYear();
	const month = String(today.getMonth() + 1).padStart(2, "0");
	const day = String(today.getDate()).padStart(2, "0");

	return `${year}-${month}-${day}`;
}

function sanitizeDirName(title) {
	return title
		.trim()
		.replace(/[\\/:*?"<>|]/g, "-")
		.replace(/\s+/g, " ");
}

function slugify(input) {
	return input
		.trim()
		.normalize("NFKD")
		.replace(/[\u0300-\u036f]/g, "")
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.replace(/-{2,}/g, "-");
}

function getExistingSlugs() {
	if (!fs.existsSync(targetDir)) {
		return new Set();
	}

	const slugs = new Set();
	const pattern = /^urlSlug:\s*['"]?([^'"\n]+)['"]?\s*$/m;
	for (const entry of fs.readdirSync(targetDir, { withFileTypes: true })) {
		if (!entry.isDirectory()) {
			continue;
		}

		const indexPath = path.join(targetDir, entry.name, "index.md");
		if (!fs.existsSync(indexPath)) {
			continue;
		}

		const match = pattern.exec(fs.readFileSync(indexPath, "utf8"));
		if (match) {
			slugs.add(match[1].trim());
		}
	}
	return slugs;
}

function getUniqueSlug(baseSlug) {
	const existingSlugs = getExistingSlugs();
	let candidate = baseSlug;
	let suffix = 2;

	while (existingSlugs.has(candidate)) {
		candidate = `${baseSlug}-${suffix}`;
		suffix += 1;
	}

	return candidate;
}

function getUniquePostDir(baseDir) {
	let candidateDir = baseDir;
	let suffix = 2;

	while (fs.existsSync(path.join(candidateDir, "index.md"))) {
		candidateDir = `${baseDir}-${suffix}`;
		suffix += 1;
	}

	return candidateDir;
}

function parseArgs(argv) {
	const cleanArgs = argv
		.slice(2)
		.filter(
			(arg, index, array) => !(arg === "--" && index === 0 && array.length > 1),
		);
	const options = { title: "", slug: "", author: "" };
	const positional = [];

	for (let i = 0; i < cleanArgs.length; i += 1) {
		const arg = cleanArgs[i];
		if (arg === "--slug") {
			options.slug = cleanArgs[++i] || "";
			continue;
		}
		if (arg.startsWith("--slug=")) {
			options.slug = arg.slice("--slug=".length);
			continue;
		}
		if (arg === "--author") {
			options.author = cleanArgs[++i] || "";
			continue;
		}
		if (arg.startsWith("--author=")) {
			options.author = arg.slice("--author=".length);
			continue;
		}
		positional.push(arg);
	}

	options.title = positional.join(" ").trim();
	return options;
}

const { title, slug, author } = parseArgs(process.argv);

if (!title) {
	console.error(`Error: No title argument provided
Usage: pnpm new-post <title> [--slug meaningful-kebab-slug] [--author author-name]`);
	process.exit(1);
}

const date = getDate();
const requestedSlug = slugify(slug || title);
if (!requestedSlug) {
	console.error("Error: Could not generate a URL slug from the title. Please pass --slug meaningful-kebab-slug.");
	process.exit(1);
}
const urlSlug = getUniqueSlug(requestedSlug);
const normalizedDirName = `${date}-${sanitizeDirName(title)}`;
const postDir = getUniquePostDir(path.join(targetDir, normalizedDirName));
const fullPath = path.join(postDir, "index.md");

if (fs.existsSync(fullPath)) {
	console.error(`Error: File ${fullPath} already exists `);
	process.exit(1);
}

if (!fs.existsSync(postDir)) {
	fs.mkdirSync(postDir, { recursive: true });
}

const content = `---
title: ${JSON.stringify(title)}
urlSlug: '${urlSlug}'
published: ${date}
description: ''
image: ''
author: ${JSON.stringify(author)}
tags: []
category: ''
draft: false
lang: 'zh_CN'
---
`;

fs.writeFileSync(fullPath, content);

console.log(`Post ${fullPath} created`);
