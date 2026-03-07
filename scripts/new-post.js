/* This is a script to create a new post markdown file with front-matter */

import fs from "fs"
import path from "path"

const targetDir = "./src/content/posts/"

function getDate() {
  const today = new Date()
  const year = today.getFullYear()
  const month = String(today.getMonth() + 1).padStart(2, "0")
  const day = String(today.getDate()).padStart(2, "0")

  return `${year}-${month}-${day}`
}

function getCompactDate(date) {
  return date.replace(/-/g, "")
}

function sanitizeDirName(title) {
  return title
    .trim()
    .replace(/[\\/:*?"<>|]/g, "-")
    .replace(/\s+/g, " ")
}

function getNextSequence(date) {
  if (!fs.existsSync(targetDir)) {
    return 1
  }

  const compactDate = getCompactDate(date)
  const pattern = new RegExp(`^urlSlug:\\s*['\"]?${compactDate}-(\\d{2})['\"]?\\s*$`, "m")
  const maxSequence = fs
    .readdirSync(targetDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const indexPath = path.join(targetDir, entry.name, "index.md")

      if (!fs.existsSync(indexPath)) {
        return 0
      }

      const content = fs.readFileSync(indexPath, "utf8")
      const match = pattern.exec(content)
      return match ? Number.parseInt(match[1], 10) : 0
    })
    .reduce((currentMax, value) => Math.max(currentMax, value), 0)

  return maxSequence + 1
}

function getUniquePostDir(baseDir) {
  let candidateDir = baseDir
  let suffix = 2

  while (fs.existsSync(path.join(candidateDir, "index.md"))) {
    candidateDir = `${baseDir}-${suffix}`
    suffix += 1
  }

  return candidateDir
}

const args = process.argv.slice(2)

if (args.length === 0) {
  console.error(`Error: No title argument provided
Usage: pnpm new-post -- <title>`)
  process.exit(1) // Terminate the script and return error code 1
}

const title = args[0].trim()
const date = getDate()
const urlSlug = `${getCompactDate(date)}-${String(getNextSequence(date)).padStart(2, "0")}`
const normalizedDirName = `${date}-${sanitizeDirName(title)}`
const postDir = getUniquePostDir(path.join(targetDir, normalizedDirName))
const fullPath = path.join(postDir, "index.md")

if (fs.existsSync(fullPath)) {
  console.error(`Error: File ${fullPath} already exists `)
  process.exit(1)
}

if (!fs.existsSync(postDir)) {
  fs.mkdirSync(postDir, { recursive: true })
}

const content = `---
title: ${JSON.stringify(title)}
urlSlug: '${urlSlug}'
published: ${date}
description: ''
image: ''
tags: []
category: ''
draft: false 
lang: ''
---
`

fs.writeFileSync(fullPath, content)

console.log(`Post ${fullPath} created`)
