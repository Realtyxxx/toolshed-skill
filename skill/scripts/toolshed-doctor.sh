#!/usr/bin/env bash
# ==============================================================================
# mem-doctor — 体检 ~/mem.md + ~/mem/*.md
#
#   1. 每篇详细文档里的 `## 自查` bash 块，逐个实际执行 —— 工具还在不在
#   2. 索引 ~/mem.md 有没有链到每一篇（漏登记 / 死链）
#   3. 每篇有没有写 `## 自查` 段
#
# 用法：bash ~/.agents/skills/toolshed/scripts/toolshed-doctor.sh [-v]
#   -v  连自查命令的输出一起打印（默认只在失败时打印）
# ==============================================================================
set -uo pipefail

# 防递归：doctor 会执行文档里的 `## 自查` 块。如果某篇文档在自查块里调了 doctor
# 自己，就会无限自我繁殖（实测几秒钟内起了上千个进程）。嵌套调用直接拒绝。
if [ -n "${MEM_DOCTOR_RUNNING:-}" ]; then
    echo "mem-doctor: 检测到嵌套调用 —— 某篇文档的 ## 自查 块里调了 doctor 自己。" >&2
    echo "            自查块只能写只读确认命令，不能调 doctor。已拒绝递归。" >&2
    exit 2
fi
export MEM_DOCTOR_RUNNING=1

MEM_INDEX="${MEM_INDEX:-$HOME/mem.md}"
MEM_DIR="${MEM_DIR:-$HOME/mem}"
CHECK_TIMEOUT="${MEM_CHECK_TIMEOUT:-30}"    # 单个自查块的执行上限，秒
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[ -t 1 ] || { RED=""; GREEN=""; YELLOW=""; DIM=""; OFF=""; }

fail=0; warn=0; pass=0

[ -f "$MEM_INDEX" ] || { echo "${RED}没有索引 $MEM_INDEX${OFF}"; exit 1; }
[ -d "$MEM_DIR" ]   || { echo "${RED}没有文档目录 $MEM_DIR${OFF}"; exit 1; }

# 抽出 `## 自查` 标题之后的第一个 fenced 代码块
extract_selfcheck() {
    awk '
        /^##[[:space:]]+自查[[:space:]]*$/ { found=1; next }
        found && !inblock && /^[[:space:]]*```/ { inblock=1; next }
        inblock && /^[[:space:]]*```/ { exit }
        inblock { print }
    ' "$1"
}

echo "索引 $MEM_INDEX"
echo "文档 $MEM_DIR"
echo

shopt -s nullglob
docs=("$MEM_DIR"/*.md)
[ ${#docs[@]} -gt 0 ] || { echo "${YELLOW}$MEM_DIR 下没有文档${OFF}"; exit 1; }

for doc in "${docs[@]}"; do
    base=$(basename "$doc")
    name="${base%.md}"
    case "$name" in _*|README|INDEX) continue ;; esac   # _TEMPLATE 之类跳过

    printf '  %-28s ' "$name"

    # 1) 索引里有没有链到它
    if ! grep -qF "mem/$base" "$MEM_INDEX"; then
        echo "${YELLOW}索引缺链接${OFF}  (~/mem.md 里没有 mem/$base)"
        warn=$((warn + 1))
        continue
    fi

    # 2) 有没有自查段
    check=$(extract_selfcheck "$doc")
    if [ -z "${check//[[:space:]]/}" ]; then
        echo "${YELLOW}缺 ## 自查 段${OFF}"
        warn=$((warn + 1))
        continue
    fi

    # 3) 跑自查（限时，避免一篇卡住拖垮整场体检）
    out=$(timeout -k 5 "$CHECK_TIMEOUT" bash -c "$check" 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
        echo "${RED}自查超时 (>${CHECK_TIMEOUT}s)${OFF}  自查块应当是秒回的只读检查"
        fail=$((fail + 1))
        continue
    fi
    if [ $rc -eq 0 ]; then
        echo "${GREEN}OK${OFF}"
        pass=$((pass + 1))
        [ $VERBOSE -eq 1 ] && [ -n "$out" ] && echo "$out" | sed "s/^/${DIM}      /;s/\$/${OFF}/"
    else
        echo "${RED}自查失败 (exit $rc)${OFF}"
        [ -n "$out" ] && echo "$out" | sed "s/^/${DIM}      /;s/\$/${OFF}/"
        fail=$((fail + 1))
    fi
done

# 4) 索引里的死链
echo
while IFS= read -r target; do
    [ -f "$MEM_DIR/$(basename "$target")" ] || {
        echo "  ${RED}索引死链${OFF}  ~/mem.md → $target（文件不存在）"
        fail=$((fail + 1))
    }
done < <(grep -o '](mem/[A-Za-z0-9._-]*\.md)' "$MEM_INDEX" |
         sed 's|^](mem/||; s|)$||' | sort -u)

echo "${GREEN}$pass 通过${OFF}  ${YELLOW}$warn 警告${OFF}  ${RED}$fail 失败${OFF}"
[ $fail -eq 0 ]
