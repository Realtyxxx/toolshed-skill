#!/usr/bin/env bash
# ==============================================================================
# toolshed-doctor — 体检 ~/toolshed.md + ~/toolshed.d/*.md
#
# 默认只做静态校验，不执行 Markdown 中的 shell。
# 只有显式传入 --run-checks，才会执行每篇的 `## 自查` bash 块。
# ==============================================================================
set -uo pipefail

RUN_CHECKS=0
VERBOSE=0

usage() {
    cat <<'EOF'
用法：toolshed-doctor.sh [--run-checks] [-v]

  默认          只检查索引、链接和 `## 自查` bash 块格式，不执行命令
  --run-checks  显式执行自查块；这些块是受信任的本地代码，不受沙箱保护
  -v            执行自查时同时打印成功命令的输出
  -h, --help    显示帮助

环境变量：
  TOOLSHED_CHECK_TIMEOUT  单个自查块的秒数上限（默认 30）
  TOOLSHED_TIMEOUT_CMD    指定 timeout 实现；设为空串则强制用内置 bash 看门狗
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --run-checks) RUN_CHECKS=1 ;;
        -v|--verbose) VERBOSE=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "toolshed-doctor: 未知参数：$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# 防递归：执行模式会把该变量传给自查子进程。任何嵌套 doctor 都直接拒绝。
if [ -n "${TOOLSHED_DOCTOR_RUNNING:-}" ]; then
    echo "toolshed-doctor: 检测到嵌套调用 —— 某篇文档的 ## 自查 块里调了 doctor 自己。" >&2
    echo "                 自查块只能写只读确认命令，不能调 doctor。已拒绝递归。" >&2
    exit 2
fi

TOOLSHED_INDEX="${TOOLSHED_INDEX:-$HOME/toolshed.md}"
TOOLSHED_DIR="${TOOLSHED_DIR:-$HOME/toolshed.d}"
CHECK_TIMEOUT="${TOOLSHED_CHECK_TIMEOUT:-30}"

case "$CHECK_TIMEOUT" in
    ''|*[!0-9]*)
        echo "toolshed-doctor: TOOLSHED_CHECK_TIMEOUT 必须是正整数" >&2
        exit 2
        ;;
esac
[ "$CHECK_TIMEOUT" -gt 0 ] || {
    echo "toolshed-doctor: TOOLSHED_CHECK_TIMEOUT 必须大于 0" >&2
    exit 2
}

# timeout(1) 属于 GNU coreutils：macOS 默认没有，homebrew 装的叫 gtimeout。
# 两个都没有时退化成纯 bash 看门狗，而不是拒绝执行 —— 否则 --run-checks 在
# 未装 coreutils 的 macOS 上完全不可用。
# TOOLSHED_TIMEOUT_CMD 可显式指定（设成空字符串即强制走看门狗）。
if [ -n "${TOOLSHED_TIMEOUT_CMD+set}" ]; then
    TIMEOUT_CMD="$TOOLSHED_TIMEOUT_CMD"
else
    TIMEOUT_CMD=""
    for candidate in timeout gtimeout; do
        if command -v "$candidate" >/dev/null 2>&1; then
            TIMEOUT_CMD="$candidate"
            break
        fi
    done
fi

# 跑一条命令，超过 $CHECK_TIMEOUT 秒杀掉。超时返回 124（timeout(1)）或
# 137/143（看门狗的 KILL/TERM）。
run_limited() {
    if [ -n "$TIMEOUT_CMD" ]; then
        "$TIMEOUT_CMD" -k 5 "$CHECK_TIMEOUT" "$@"
        return $?
    fi

    "$@" &
    local cmd_pid=$!
    # 看门狗的 stdout 必须挪开：否则它会一直攥着调用方的命令替换管道不放，
    # 自查秒回也得干等满一个超时周期。
    (
        sleep "$CHECK_TIMEOUT"
        kill -TERM "$cmd_pid" 2>/dev/null
        sleep 5
        kill -KILL "$cmd_pid" 2>/dev/null
    ) >/dev/null 2>&1 &
    local watchdog_pid=$!

    wait "$cmd_pid"
    local rc=$?
    kill -TERM "$watchdog_pid" 2>/dev/null
    wait "$watchdog_pid" 2>/dev/null
    return $rc
}

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[ -t 1 ] || { RED=""; GREEN=""; YELLOW=""; DIM=""; OFF=""; }

fail=0
pass=0

[ -f "$TOOLSHED_INDEX" ] || { echo "${RED}没有索引 $TOOLSHED_INDEX${OFF}"; exit 1; }
[ -d "$TOOLSHED_DIR" ]   || { echo "${RED}没有文档目录 $TOOLSHED_DIR${OFF}"; exit 1; }

# 输出 `## 自查` 下唯一允许的 ```bash 块。
# 返回码：2=缺标题，3=标题后缺 bash 块，4=首个 fence 不是 bash，5=代码块未闭合。
extract_selfcheck() {
    awk '
        BEGIN { status=2 }
        /^##[[:space:]]+自查[[:space:]]*$/ && !found {
            found=1
            status=3
            next
        }
        found && !inblock && /^##[[:space:]]+/ { exit }
        found && !inblock && /^[[:space:]]*```bash[[:space:]]*$/ {
            inblock=1
            status=5
            next
        }
        found && !inblock && /^[[:space:]]*```/ {
            status=4
            exit
        }
        inblock && /^[[:space:]]*```[[:space:]]*$/ {
            status=0
            exit
        }
        inblock { print }
        END { exit status }
    ' "$1"
}

echo "索引 $TOOLSHED_INDEX"
echo "文档 $TOOLSHED_DIR"
if [ "$RUN_CHECKS" -eq 1 ]; then
    echo "模式 执行受信任的自查命令"
else
    echo "模式 静态校验（未执行任何自查命令）"
fi
echo

shopt -s nullglob
docs=("$TOOLSHED_DIR"/*.md)
[ ${#docs[@]} -gt 0 ] || { echo "${RED}$TOOLSHED_DIR 下没有文档${OFF}"; exit 1; }

for doc in "${docs[@]}"; do
    base=$(basename "$doc")
    name="${base%.md}"
    case "$name" in _*|README|INDEX) continue ;; esac

    printf '  %-28s ' "$name"

    if ! grep -qF "toolshed.d/$base" "$TOOLSHED_INDEX"; then
        echo "${RED}索引缺链接${OFF}  (~/toolshed.md 里没有 toolshed.d/$base)"
        fail=$((fail + 1))
        continue
    fi

    check=$(extract_selfcheck "$doc")
    extract_rc=$?
    case "$extract_rc" in
        0) ;;
        2) echo "${RED}缺 ## 自查 段${OFF}" ;;
        3) echo "${RED}## 自查 后缺少 bash 代码块${OFF}" ;;
        4) echo "${RED}## 自查 的首个代码块必须标记为 bash${OFF}" ;;
        5) echo "${RED}## 自查 的 bash 代码块未闭合${OFF}" ;;
        *) echo "${RED}无法解析 ## 自查 段 (exit $extract_rc)${OFF}" ;;
    esac
    if [ "$extract_rc" -ne 0 ]; then
        fail=$((fail + 1))
        continue
    fi
    if [ -z "${check//[[:space:]]/}" ]; then
        echo "${RED}## 自查 的 bash 代码块为空${OFF}"
        fail=$((fail + 1))
        continue
    fi

    if [ "$RUN_CHECKS" -eq 0 ]; then
        echo "${GREEN}OK（静态）${OFF}"
        pass=$((pass + 1))
        continue
    fi

    echo "${YELLOW}RUN${OFF}"
    printf '%s\n' "$check" | sed "s/^/${DIM}      /;s/\$/${OFF}/"

    # 自查从 HOME 启动，并仅继承执行检查所需的非敏感环境变量。
    run_env=(env -i "HOME=$HOME" "PATH=${PATH:-/usr/bin:/bin}" "TOOLSHED_DOCTOR_RUNNING=1")
    for key in USER LOGNAME LANG LC_ALL TERM TMPDIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_RUNTIME_DIR; do
        value="${!key:-}"
        [ -n "$value" ] && run_env+=("$key=$value")
    done

    out=$(cd "$HOME" && run_limited "${run_env[@]}" \
        bash --noprofile --norc -c "$check" 2>&1)
    rc=$?

    printf '  %-28s ' ""
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
        echo "${RED}自查超时 (>${CHECK_TIMEOUT}s)${OFF}"
        fail=$((fail + 1))
    elif [ "$rc" -eq 0 ]; then
        echo "${GREEN}OK${OFF}"
        pass=$((pass + 1))
        [ "$VERBOSE" -eq 1 ] && [ -n "$out" ] && printf '%s\n' "$out" | sed "s/^/${DIM}      /;s/\$/${OFF}/"
    else
        echo "${RED}自查失败 (exit $rc)${OFF}"
        [ -n "$out" ] && printf '%s\n' "$out" | sed "s/^/${DIM}      /;s/\$/${OFF}/"
        fail=$((fail + 1))
    fi
done

echo
while IFS= read -r target; do
    [ -f "$TOOLSHED_DIR/$(basename "$target")" ] || {
        echo "  ${RED}索引死链${OFF}  ~/toolshed.md → $target（文件不存在）"
        fail=$((fail + 1))
    }
done < <(grep -o '](toolshed\.d/[A-Za-z0-9._-]*\.md)' "$TOOLSHED_INDEX" |
         sed 's|^](toolshed\.d/||; s|)$||' | sort -u)

echo "${GREEN}$pass 通过${OFF}  ${RED}$fail 失败${OFF}"
[ "$fail" -eq 0 ]
