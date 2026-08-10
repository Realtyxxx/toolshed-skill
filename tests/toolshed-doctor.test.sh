#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/skill/scripts/toolshed-doctor.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

pass=0

new_case() {
    local name=$1
    CASE_HOME="$TEST_ROOT/$name/home"
    mkdir -p "$CASE_HOME/toolshed.d"
    CASE_INDEX="$CASE_HOME/toolshed.md"
    CASE_DIR="$CASE_HOME/toolshed.d"
}

run_expect() {
    local expected=$1
    shift
    set +e
    OUTPUT=$(HOME="$CASE_HOME" TOOLSHED_INDEX="$CASE_INDEX" TOOLSHED_DIR="$CASE_DIR" \
        bash "$DOCTOR" "$@" 2>&1)
    RC=$?
    set -e
    if [ "$RC" -ne "$expected" ]; then
        echo "期望 exit $expected，实际 exit $RC" >&2
        echo "$OUTPUT" >&2
        exit 1
    fi
    pass=$((pass + 1))
}

new_case static-does-not-run
cat > "$CASE_INDEX" <<'EOF'
[demo](toolshed.d/demo.md)
EOF
cat > "$CASE_DIR/demo.md" <<'EOF'
# demo

## 自查

```bash
touch "$HOME/executed"
```
EOF
run_expect 0
[ ! -e "$CASE_HOME/executed" ] || { echo "默认模式不应执行自查" >&2; exit 1; }
[[ "$OUTPUT" == *"静态校验"* ]] || { echo "默认模式输出缺少静态标识" >&2; exit 1; }

run_expect 0 --run-checks
[ -e "$CASE_HOME/executed" ] || { echo "--run-checks 应执行自查" >&2; exit 1; }
[[ "$OUTPUT" == *'touch "$HOME/executed"'* ]] || { echo "执行前应打印命令" >&2; exit 1; }

new_case missing-selfcheck
echo '[demo](toolshed.d/demo.md)' > "$CASE_INDEX"
echo '# demo' > "$CASE_DIR/demo.md"
run_expect 1
[[ "$OUTPUT" == *"缺 ## 自查"* ]] || { echo "应报告缺少自查" >&2; exit 1; }

new_case wrong-fence
echo '[demo](toolshed.d/demo.md)' > "$CASE_INDEX"
cat > "$CASE_DIR/demo.md" <<'EOF'
## 自查

```sh
true
```
EOF
run_expect 1
[[ "$OUTPUT" == *"必须标记为 bash"* ]] || { echo "应拒绝非 bash fence" >&2; exit 1; }

new_case missing-index-link
echo '# toolshed' > "$CASE_INDEX"
cat > "$CASE_DIR/demo.md" <<'EOF'
## 自查

```bash
true
```
EOF
run_expect 1
[[ "$OUTPUT" == *"索引缺链接"* ]] || { echo "缺链接应失败" >&2; exit 1; }

new_case unknown-option
echo '[demo](toolshed.d/demo.md)' > "$CASE_INDEX"
cat > "$CASE_DIR/demo.md" <<'EOF'
## 自查

```bash
true
```
EOF
run_expect 2 --unknown
[[ "$OUTPUT" == *"未知参数"* ]] || { echo "未知参数应被拒绝" >&2; exit 1; }

echo "$pass tests passed"
