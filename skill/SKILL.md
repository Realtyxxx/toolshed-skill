---
name: toolshed
description: Record a newly built or installed global/reusable tool into the user's local tool memory at ~/mem.md + ~/mem/<tool>.md. Use when you have just created, installed, or configured something that lives beyond this one task — a script placed on PATH (~/.local/bin, /usr/local/bin), a daemon or background service, a shell rc / login hook, a global config directory (~/.config/<tool>/, ~/.claude/, ~/.codex/), a globally registered skill / hook / MCP server / cron job, or any script designed for reuse across projects. Also use when the user says "记一下"/"记到 mem"/"写进 mem"/"更新 mem", when they ask what local tools exist or how one works, or before rebuilding something that may already exist. Do NOT use for one-off throwaway scripts, project-local code that ships with its repo, or plain usage of standard ecosystem commands.
---

# mem — 本机工具记忆

本机上由 AI 搭建/安装的**全局、可复用**工具，统一记在两个地方：

- `~/mem.md` —— 索引 + 命令速查。一个工具一段，几行就够，用来**路由**。
- `~/mem/<tool>.md` —— 一个工具一篇详细文档：原理、全部常用命令、自查、踩坑。

跨 agent 共享（claude / codex / gemini 都读得到），所以是普通 Markdown，不进任何 agent 私有的 memory 格式。

## 第一步：先查，再决定写

动手记之前先看有没有：

```bash
grep -il '<tool>' ~/mem.md ~/mem/*.md
```

**已有条目就更新那一篇，绝不新建重复文件。** 更新时保留原有的踩坑段——那些是花代价换来的。

## 第二步：判定该不该记

### 记（全局 / 可复用）

命中任意一条就记：

- 可执行文件落到了 PATH 上：`~/.local/bin/`、`/usr/local/bin/`、`~/bin/`
- 改了登录 shell：`~/.zshrc`、`~/.bashrc`、`~/env.d/`
- 在全局配置目录下新增了一套配置：`~/.config/<tool>/`、`~/.claude/`、`~/.codex/`
- 全局注册：skill（`~/.agents/skills/`）、hook（`settings.json`）、MCP server、cron / 定时任务
- 有守护进程、后台服务或占端口
- 设计上跨项目复用——**即使目前只有一个项目在用**
- 有非显然的运维面：需要启停、会被别的东西悄悄覆盖、配置会漂移

### 不记（ad-hoc）

- 一次性脚本：`$CLAUDE_JOB_DIR/tmp`、`/tmp`，跑完即弃
- 只对某个仓库有意义、随仓库走的东西 → 写进**那个仓库**的 `README` / `CLAUDE.md`
- 单行 alias 或一句 shell 管道（成套的除外）
- 语言生态标准命令的普通用法（`npm`、`pytest`、`git`）——除非本机有特殊配置
- `--help` 已经说清楚、且本机没有任何特有配置的东西

### 灰色地带

先按"不记"走。但只要**第二次**又要向人解释它，就记下来——重复解释是它已经变成基础设施的信号。

## 第三步：写

### 时机

**在工具跑通之后立刻写**，不要攒到最后。此时上下文最全，命令的真实输出、踩过的坑、为什么这么配都还在手上；隔一天再补必然缩水成一份 `--help` 的复述。

### 事实来源

文档里的每一条都要有出处，**不凭印象写**：

- 读源码 / 读配置文件（`~/.config/<tool>/config.toml`、`settings.json`）
- 实际跑 `<tool> --help`、跑一遍主命令看真实输出
- `ps` 确认守护进程真在跑、`stat`/`readlink` 确认路径真实

写完前自己核一遍：文档里出现的每个路径、端口、flag 都真实存在。

### 详细文档：`~/mem/<tool>.md`

骨架见 `references/TEMPLATE.md`，照它写。要点：

- **开头两三句讲"解决什么问题、什么时候该想起它"**，不是讲它是什么。半年后翻到这里的人需要的是"我现在这个场景该不该用它"。
- **常用命令只列你真的会用的那几条**，带上默认值陷阱（比如"默认只出前 200 条"）。不要抄 `--help` 全文——那是它自己的事。
- **`## 自查` 段必须有**，一个 fenced bash 块，能一眼确认这东西还活着（`command -v` / `--version` / 检查 pidfile）。`scripts/toolshed-doctor.sh` 会自动提取并**实际执行**它们，所以：
  - 只写**只读**命令。绝不启停服务、写文件、发网络请求。
  - **绝不在自查块里调 `toolshed-doctor.sh` 自己**——doctor 正在执行这段，会无限自我繁殖（实测几秒起了上千个进程）。doctor 现在有嵌套护栏会拒绝，但别去撞它。
  - 秒回。单块超过 30s 判超时失败。
  - 标题必须正好是 `## 自查`，代码块必须是标题后的第一个 fenced 块——提取靠这个位置匹配。
- **`## 注意事项` 是全篇最有价值的一段。** 优先写：静默失败（坏了但不报错）、会被什么覆盖、默认截断、共享机器上的坑、改一处要同步改的另一处。
- 绝不写密钥本身（token、PAT、密码）。写"从哪拿"，不写值。
- 日期写绝对日期（`2026-08-07`），不写"上周"。

### 索引条目：`~/mem.md`

在 `~/mem.md` 追加一段：

```markdown
## <name> — <一句话定位>

<什么场景下该想起它，一到两句>
详细：[`~/mem/<name>.md`](mem/<name>.md)

​```bash
<3-6 条最常用命令，带简短行内注释>
​```

- <关键路径 / 端口 / 配置文件>
- **坑**：<一条最容易踩的>
```

索引要能**独立完成路由**：光看 `~/mem.md` 就知道该不该点进详细文档。所以定位句要写场景，不要只写工具名的同义反复。

## 第四步：验收

```bash
bash ~/.agents/skills/toolshed/scripts/toolshed-doctor.sh
```

它会遍历 `~/mem/*.md`，跑每篇的 `## 自查` 块，并检查索引 `~/mem.md` 里有没有对应链接。新写完的条目应当全绿。

## 反向用法：干活前先查 mem

看到本机上不认识的命令、或者准备造一个可能已经存在的轮子时：

```bash
grep -il '<关键词>' ~/mem.md ~/mem/*.md   # 命中就先读那一篇
```

`~/mem.md` 很短，不确定时整篇读掉比猜便宜。
