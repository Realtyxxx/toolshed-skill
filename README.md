# toolshed

一个 agent skill：把本机上**全局、可复用**的工具（PATH 上的脚本、守护进程、shell hook、全局配置、注册的 skill/hook/MCP/cron）记进 `~/toolshed.md` + `~/toolshed.d/<tool>.md`，跨 agent（claude / codex / gemini）共享。

## 安装

```bash
npx github:Realtyxxx/toolshed-skill            # → ~/.agents/skills/toolshed
npx github:Realtyxxx/toolshed-skill --claude   # → ~/.claude/skills/toolshed
npx github:Realtyxxx/toolshed-skill --dir ./skills
npx github:Realtyxxx/toolshed-skill --force    # 覆盖重装
```

安装器会打印实际安装目录和对应的 doctor 命令；`--claude`、`--dir` 不依赖 `~/.agents` 的固定路径。

## 体检

```bash
bash ~/.agents/skills/toolshed/scripts/toolshed-doctor.sh               # 静态校验，不执行 Markdown 命令
bash ~/.agents/skills/toolshed/scripts/toolshed-doctor.sh --run-checks  # 显式执行受信任的自查块
```

静态模式检查 `~/toolshed.d/*.md` 的 `## 自查` bash 块格式、索引缺失和死链。`--run-checks` 会在打印命令后实际执行这些本地代码；它们不受沙箱保护，只能用于受信任、只读、秒回的检查。

## 测试

```bash
npm test
```

## 内容

```
skill/
  SKILL.md                    # skill 本体
  references/TEMPLATE.md      # 详细文档骨架
  scripts/toolshed-doctor.sh  # 体检脚本
tests/
  toolshed-doctor.test.sh     # 无第三方依赖的回归测试
```

MIT.
