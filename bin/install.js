#!/usr/bin/env node
// 把 skill/ 安装到 agent 的 skills 目录下。默认 ~/.agents/skills/toolshed
// —— SKILL.md 里的 doctor 路径就是按这个目录写死的。

const fs = require('fs');
const os = require('os');
const path = require('path');

const SKILL_NAME = 'toolshed';
const SRC = path.join(__dirname, '..', 'skill');

const args = process.argv.slice(2);
const has = (f) => args.includes(f);

if (has('-h') || has('--help')) {
  console.log(`
toolshed-skill — 安装 toolshed skill

  npx github:Realtyxxx/toolshed-skill            # 装到 ~/.agents/skills/toolshed
  npx github:Realtyxxx/toolshed-skill --claude   # 装到 ~/.claude/skills/toolshed
  npx github:Realtyxxx/toolshed-skill --dir <路径>  # 装到指定 skills 根目录
  npx github:Realtyxxx/toolshed-skill --force    # 覆盖已存在的安装
`);
  process.exit(0);
}

let root = path.join(os.homedir(), '.agents', 'skills');
const dirIdx = args.indexOf('--dir');
if (dirIdx !== -1) {
  if (!args[dirIdx + 1]) {
    console.error('--dir 需要一个路径参数');
    process.exit(1);
  }
  root = path.resolve(args[dirIdx + 1]);
} else if (has('--claude')) {
  root = path.join(os.homedir(), '.claude', 'skills');
}

const dest = path.join(root, SKILL_NAME);

if (fs.existsSync(dest) && !has('--force')) {
  console.error(`已存在：${dest}`);
  console.error('要覆盖请加 --force（会先删除该目录）。');
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.mkdirSync(root, { recursive: true });
fs.cpSync(SRC, dest, { recursive: true });

// 保证 doctor 可执行——npm 打包会丢掉部分平台上的执行位。
const doctor = path.join(dest, 'scripts', 'toolshed-doctor.sh');
if (fs.existsSync(doctor)) fs.chmodSync(doctor, 0o755);

console.log(`已安装 toolshed skill → ${dest}`);
console.log(`体检：bash ${doctor}`);
