# toolshed

一个 agent skill：把本机上**全局、可复用**的工具（PATH 上的脚本、守护进程、shell hook、全局配置、注册的 skill/hook/MCP/cron）记进 `~/toolshed.md` + `~/toolshed.d/<tool>.md`，跨 agent（claude / codex / gemini）共享。

## 安装

```bash
npx github:Realtyxxx/toolshed-skill            # → ~/.agents/skills/toolshed
npx github:Realtyxxx/toolshed-skill --claude   # → ~/.claude/skills/toolshed
npx github:Realtyxxx/toolshed-skill --dir ./skills
npx github:Realtyxxx/toolshed-skill --force    # 覆盖重装
```

默认装到 `~/.agents/skills/toolshed`，因为 `SKILL.md` 里的 doctor 路径按这个目录写。

## 体检

```bash
bash ~/.agents/skills/toolshed/scripts/toolshed-doctor.sh
```

遍历 `~/toolshed.d/*.md`，实际执行每篇的 `## 自查` bash 块，并检查 `~/toolshed.md` 索引里有没有对应链接。

## 内容

```
skill/
  SKILL.md                    # skill 本体
  references/TEMPLATE.md      # 详细文档骨架
  scripts/toolshed-doctor.sh  # 体检脚本
```

MIT.
