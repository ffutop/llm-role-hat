#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT="$ROOT_DIR/bin/hat"
TMP_DIR="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/hat-tests.XXXXXX")" && pwd)"
trap 'rm -rf "$TMP_DIR"' EXIT

export HAT_HOME="$TMP_DIR/home"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "expected file: $1"; }
assert_dir() { [ -d "$1" ] || fail "expected directory: $1"; }
assert_link_to() { [ -L "$1" ] || fail "expected symlink: $1"; [ -e "$1" ] || fail "broken symlink: $1"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected '$2' in: $1"; }

echo '1. roles are created once and never repaired implicitly'
"$HAT" role create architect
assert_dir "$HAT_HOME/architect/skills"
for adapter in claude codex qwen copilot; do
  assert_link_to "$HAT_HOME/architect/adapters/$adapter/skills"
done
if "$HAT" role create architect >"$TMP_DIR/duplicate.out" 2>&1; then
  fail 'duplicate role creation must fail'
fi

echo '2. copying a standard skill into a role is atomic'
mkdir -p "$TMP_DIR/source/tdd"
printf '%s\n' '---' 'name: tdd' 'description: Test-first work.' '---' > "$TMP_DIR/source/tdd/SKILL.md"
"$HAT" role add-skill architect "$TMP_DIR/source/tdd" tdd
assert_file "$HAT_HOME/architect/skills/tdd/SKILL.md"
assert_file "$HAT_HOME/architect/skills/tdd/.hat-skill"
if "$HAT" role add-skill architect "$TMP_DIR/source/tdd" tdd >"$TMP_DIR/duplicate-skill.out" 2>&1; then
  fail 'duplicate role skill copy must fail'
fi
if "$HAT" role add-skill architect "$TMP_DIR/source/tdd" architecture/tdd >"$TMP_DIR/nested-skill.out" 2>&1; then
  fail 'nested skill names must fail'
fi

echo '3. a damaged adapter rejects a skill without copying it into the role'
"$HAT" role create finance
mkdir -p "$TMP_DIR/source/review"
printf '%s\n' '---' 'name: review' 'description: Review work.' '---' > "$TMP_DIR/source/review/SKILL.md"
rm "$HAT_HOME/finance/adapters/copilot/skills"
if "$HAT" role add-skill finance "$TMP_DIR/source/review" review >"$TMP_DIR/atomic.out" 2>&1; then
  fail 'adding a skill with a damaged adapter must fail'
fi
[ ! -e "$HAT_HOME/finance/skills/review" ] || fail 'failed add must not leave a partial role copy'

echo '4. run only accepts registered adapters and preserves the current directory'
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/work"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$PWD|$CODEX_HOME"' > "$TMP_DIR/bin/codex"
chmod +x "$TMP_DIR/bin/codex"
RUN_OUT="$(cd "$TMP_DIR/work" && PATH="$TMP_DIR/bin:$PATH" "$HAT" run architect -- codex)"
assert_contains "$RUN_OUT" "$TMP_DIR/work|$HAT_HOME/architect/adapters/codex"
if "$HAT" run architect -- unknown-cli >"$TMP_DIR/unknown.out" 2>&1; then
  fail 'unknown adapters must fail'
fi

echo '5. role auth links share existing files and create missing source files'
AUTH_HOME="$TMP_DIR/auth-home"
mkdir -p "$AUTH_HOME/.codex"
printf '%s\n' '{"token":"fixture"}' > "$AUTH_HOME/.codex/auth.json"
HOME="$AUTH_HOME" "$HAT" role share-auth architect codex
assert_link_to "$HAT_HOME/architect/adapters/codex/auth.json"
[ "$(readlink "$HAT_HOME/architect/adapters/codex/auth.json")" = "$AUTH_HOME/.codex/auth.json" ] || fail 'Codex auth link must target the default auth file'
HOME="$AUTH_HOME" "$HAT" role share-auth architect claude
assert_file "$AUTH_HOME/.claude/.credentials.json"
[ "$(stat -f '%Lp' "$AUTH_HOME/.claude/.credentials.json")" = 600 ] || fail 'created credential source must be mode 600'
assert_link_to "$HAT_HOME/architect/adapters/claude/.credentials.json"
[ "$(readlink "$HAT_HOME/architect/adapters/claude/.credentials.json")" = "$AUTH_HOME/.claude/.credentials.json" ] || fail 'Claude credential link must target the default credential file'
if HOME="$AUTH_HOME" "$HAT" role share-auth architect qwen >"$TMP_DIR/auth-adapter.out" 2>&1; then
  fail 'unsupported auth adapter must fail'
fi
"$HAT" role create reviewer
printf '%s\n' 'keep-me' > "$HAT_HOME/reviewer/adapters/codex/auth.json"
if HOME="$AUTH_HOME" "$HAT" role share-auth reviewer codex >"$TMP_DIR/auth-conflict.out" 2>&1; then
  fail 'existing auth target must not be replaced'
fi
assert_contains "$(<"$HAT_HOME/reviewer/adapters/codex/auth.json")" 'keep-me'

echo '6. doctor is read-only and detects an invalid local skill'
rm "$HAT_HOME/architect/skills/tdd/SKILL.md"
if "$HAT" role doctor architect >"$TMP_DIR/doctor.out" 2>&1; then
  fail 'doctor must fail on an invalid local skill'
fi
assert_contains "$(<"$TMP_DIR/doctor.out")" 'invalid local skill'

echo '7. shell shortcut installation is append-only and idempotent'
RC_FILE="$TMP_DIR/bashrc"
printf '%s\n' '# existing user setting' > "$RC_FILE"
"$HAT" shortcut install bash "$RC_FILE"
assert_contains "$(<"$RC_FILE")" '# existing user setting'
assert_contains "$(<"$RC_FILE")" '# >>> hat role shortcuts >>>'
assert_contains "$(<"$RC_FILE")" 'hat run "$role" -- codex "$@"'
mkdir -p "$TMP_DIR/shortcut-bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*"' > "$TMP_DIR/shortcut-bin/hat"
chmod +x "$TMP_DIR/shortcut-bin/hat"
WRAPPER_OUT="$(PATH="$TMP_DIR/shortcut-bin:$PATH" bash -c 'source "$1"; codex @architect --resume' -- "$RC_FILE")"
assert_contains "$WRAPPER_OUT" 'run architect -- codex --resume'
SHORTCUT_BLOCKS="$(grep -c '^# >>> hat role shortcuts >>>$' "$RC_FILE")"
"$HAT" shortcut install bash "$RC_FILE"
[ "$(grep -c '^# >>> hat role shortcuts >>>$' "$RC_FILE")" = "$SHORTCUT_BLOCKS" ] || fail 'shortcut installation must not duplicate its block'
printf '%s\n' '# >>> hat role shortcuts >>>' > "$TMP_DIR/incomplete-rc"
if "$HAT" shortcut install bash "$TMP_DIR/incomplete-rc" >"$TMP_DIR/incomplete.out" 2>&1; then
  fail 'incomplete shortcut block must fail'
fi

echo '8. the installer ships the current command'
INSTALL_PREFIX="$TMP_DIR/install-prefix"
PREFIX="$INSTALL_PREFIX" HAT_DOWNLOAD_URL="file://$ROOT_DIR/bin/hat" "$ROOT_DIR/install.sh" >"$TMP_DIR/install.out"
assert_file "$INSTALL_PREFIX/bin/hat"
assert_contains "$("$INSTALL_PREFIX/bin/hat" help)" 'hat shortcut install <bash|zsh> [rc-file]'

echo '9. bash completion suggests commands, subcommands, and live role names'
"$HAT" completion bash > "$TMP_DIR/hat-completion.bash"
assert_contains "$(<"$TMP_DIR/hat-completion.bash")" '_hat_completion'
TOP_LEVEL="$(PATH="$ROOT_DIR/bin:$PATH" bash -c '
  source "$1"
  COMP_WORDS=(hat "")
  COMP_CWORD=1
  _hat_completion
  printf "%s\n" "${COMPREPLY[@]}"
' -- "$TMP_DIR/hat-completion.bash")"
assert_contains "$TOP_LEVEL" 'completion'
assert_contains "$TOP_LEVEL" 'shortcut'
ROLE_COMPLETIONS="$(PATH="$ROOT_DIR/bin:$PATH" bash -c '
  source "$1"
  COMP_WORDS=(hat role add-skill "")
  COMP_CWORD=3
  _hat_completion
  printf "%s\n" "${COMPREPLY[@]}"
' -- "$TMP_DIR/hat-completion.bash")"
assert_contains "$ROLE_COMPLETIONS" 'architect'
assert_contains "$ROLE_COMPLETIONS" 'reviewer'
COMPLETION_SUBCOMMANDS="$(PATH="$ROOT_DIR/bin:$PATH" bash -c '
  source "$1"
  COMP_WORDS=(hat completion "")
  COMP_CWORD=2
  _hat_completion
  printf "%s\n" "${COMPREPLY[@]}"
' -- "$TMP_DIR/hat-completion.bash")"
assert_contains "$COMPLETION_SUBCOMMANDS" 'install'

echo '10. shell completion installation is append-only, idempotent, and wires real completion'
COMP_RC_BASH="$TMP_DIR/bashrc-completion"
printf '%s\n' '# existing user setting' > "$COMP_RC_BASH"
"$HAT" completion install bash "$COMP_RC_BASH"
assert_contains "$(<"$COMP_RC_BASH")" '# existing user setting'
assert_contains "$(<"$COMP_RC_BASH")" '# >>> hat completion >>>'
assert_contains "$(<"$COMP_RC_BASH")" 'hat completion bash'
COMPLETION_BLOCKS="$(grep -c '^# >>> hat completion >>>$' "$COMP_RC_BASH")"
"$HAT" completion install bash "$COMP_RC_BASH"
[ "$(grep -c '^# >>> hat completion >>>$' "$COMP_RC_BASH")" = "$COMPLETION_BLOCKS" ] || fail 'completion installation must not duplicate its block'
printf '%s\n' '# >>> hat completion >>>' > "$TMP_DIR/incomplete-completion-rc"
if "$HAT" completion install bash "$TMP_DIR/incomplete-completion-rc" >"$TMP_DIR/incomplete-completion.out" 2>&1; then
  fail 'incomplete completion block must fail'
fi
RC_FUNCTION_CHECK="$(PATH="$ROOT_DIR/bin:$PATH" bash -c 'source "$1"; type -t _hat_completion' -- "$COMP_RC_BASH")"
[ "$RC_FUNCTION_CHECK" = 'function' ] || fail 'sourcing the installed bash rc block must register _hat_completion'

COMP_RC_ZSH="$TMP_DIR/zshrc-completion"
printf '%s\n' '# existing zsh setting' > "$COMP_RC_ZSH"
"$HAT" completion install zsh "$COMP_RC_ZSH"
assert_contains "$(<"$COMP_RC_ZSH")" '# existing zsh setting'
assert_contains "$(<"$COMP_RC_ZSH")" '# >>> hat completion >>>'
assert_contains "$(<"$COMP_RC_ZSH")" 'compinit'
assert_contains "$(<"$COMP_RC_ZSH")" 'hat completion zsh'
"$HAT" completion install zsh "$COMP_RC_ZSH"
[ "$(grep -c '^# >>> hat completion >>>$' "$COMP_RC_ZSH")" = 1 ] || fail 'zsh completion installation must not duplicate its block'
if command -v zsh >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  ZSH_REGISTERED="$(timeout 10 env PATH="$ROOT_DIR/bin:$PATH" HAT_HOME="$HAT_HOME" zsh -f -c 'source "$1"; print -r -- "$+_comps[hat]"' -- "$COMP_RC_ZSH" 2>"$TMP_DIR/zsh-completion.err" || true)"
  [ "$ZSH_REGISTERED" = '1' ] || fail "sourcing the installed zsh rc block must register hat completion (got '$ZSH_REGISTERED'): $(<"$TMP_DIR/zsh-completion.err")"
fi

echo '11. a single shared proxy is set, injected into hat run for every role, and cleanly unset'
[ "$("$HAT" proxy show)" = 'no proxy configured' ] || fail 'a fresh hat home must report no proxy configured'
if "$HAT" proxy set not-a-url >"$TMP_DIR/proxy-invalid.out" 2>&1; then
  fail 'an invalid proxy url must be rejected'
fi
"$HAT" proxy set http://localhost:8008
assert_file "$HAT_HOME/proxy"
[ "$(<"$HAT_HOME/proxy")" = 'http://localhost:8008' ] || fail 'proxy file must contain the configured url'
[ "$("$HAT" proxy show)" = 'http://localhost:8008' ] || fail 'proxy show must print the configured url'
"$HAT" proxy set http://localhost:9009
[ "$(<"$HAT_HOME/proxy")" = 'http://localhost:9009' ] || fail 'proxy set must overwrite an existing proxy'

mkdir -p "$TMP_DIR/proxy-bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s|%s|%s|%s\n" "${HTTP_PROXY:-unset}" "${HTTPS_PROXY:-unset}" "${http_proxy:-unset}" "${https_proxy:-unset}"' > "$TMP_DIR/proxy-bin/codex"
chmod +x "$TMP_DIR/proxy-bin/codex"
PROXY_RUN_OUT="$(env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy PATH="$TMP_DIR/proxy-bin:$PATH" "$HAT" run architect -- codex)"
[ "$PROXY_RUN_OUT" = 'http://localhost:9009|http://localhost:9009|http://localhost:9009|http://localhost:9009' ] || fail "hat run must export the shared proxy in upper and lower case: $PROXY_RUN_OUT"
PROXY_RUN_OUT_2="$(env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy PATH="$TMP_DIR/proxy-bin:$PATH" "$HAT" run finance -- codex)"
[ "$PROXY_RUN_OUT_2" = 'http://localhost:9009|http://localhost:9009|http://localhost:9009|http://localhost:9009' ] || fail "the shared proxy must apply the same way to every role: $PROXY_RUN_OUT_2"

"$HAT" proxy unset
[ ! -e "$HAT_HOME/proxy" ] || fail 'proxy unset must remove the proxy file'
[ "$("$HAT" proxy show)" = 'no proxy configured' ] || fail 'proxy show must report no proxy after unset'
AMBIENT_RUN_OUT="$(env -u http_proxy -u https_proxy HTTP_PROXY='http://ambient:1' HTTPS_PROXY='http://ambient:1' PATH="$TMP_DIR/proxy-bin:$PATH" "$HAT" run architect -- codex)"
[ "$AMBIENT_RUN_OUT" = 'http://ambient:1|http://ambient:1|unset|unset' ] || fail "hat run must leave the ambient proxy untouched when no shared proxy is configured: $AMBIENT_RUN_OUT"

echo '12. a single shared no-proxy list is set, injected into hat run for every role, and cleanly unset'
[ "$("$HAT" no-proxy show)" = 'no no-proxy configured' ] || fail 'a fresh hat home must report no no-proxy configured'
if "$HAT" no-proxy set 'bad host' >"$TMP_DIR/no-proxy-invalid.out" 2>&1; then
  fail 'an invalid no-proxy value must be rejected'
fi
"$HAT" no-proxy set 'localhost,.internal'
assert_file "$HAT_HOME/no_proxy"
[ "$(<"$HAT_HOME/no_proxy")" = 'localhost,.internal' ] || fail 'no_proxy file must contain the configured value'
[ "$("$HAT" no-proxy show)" = 'localhost,.internal' ] || fail 'no-proxy show must print the configured value'
"$HAT" no-proxy set '*.example.com,10.0.0.1:8080,*'
[ "$(<"$HAT_HOME/no_proxy")" = '*.example.com,10.0.0.1:8080,*' ] || fail 'no-proxy set must overwrite an existing no-proxy value'

mkdir -p "$TMP_DIR/no-proxy-bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s|%s\n" "${NO_PROXY:-unset}" "${no_proxy:-unset}"' > "$TMP_DIR/no-proxy-bin/codex"
chmod +x "$TMP_DIR/no-proxy-bin/codex"
NO_PROXY_RUN_OUT="$(env -u NO_PROXY -u no_proxy PATH="$TMP_DIR/no-proxy-bin:$PATH" "$HAT" run architect -- codex)"
[ "$NO_PROXY_RUN_OUT" = '*.example.com,10.0.0.1:8080,*|*.example.com,10.0.0.1:8080,*' ] || fail "hat run must export the shared no-proxy list in upper and lower case: $NO_PROXY_RUN_OUT"
NO_PROXY_RUN_OUT_2="$(env -u NO_PROXY -u no_proxy PATH="$TMP_DIR/no-proxy-bin:$PATH" "$HAT" run finance -- codex)"
[ "$NO_PROXY_RUN_OUT_2" = '*.example.com,10.0.0.1:8080,*|*.example.com,10.0.0.1:8080,*' ] || fail "the shared no-proxy list must apply the same way to every role: $NO_PROXY_RUN_OUT_2"

"$HAT" no-proxy unset
[ ! -e "$HAT_HOME/no_proxy" ] || fail 'no-proxy unset must remove the no_proxy file'
[ "$("$HAT" no-proxy show)" = 'no no-proxy configured' ] || fail 'no-proxy show must report no no-proxy after unset'
AMBIENT_NO_PROXY_RUN_OUT="$(env -u no_proxy NO_PROXY='ambient' PATH="$TMP_DIR/no-proxy-bin:$PATH" "$HAT" run architect -- codex)"
[ "$AMBIENT_NO_PROXY_RUN_OUT" = 'ambient|unset' ] || fail "hat run must leave the ambient no-proxy value untouched when no shared no-proxy list is configured: $AMBIENT_NO_PROXY_RUN_OUT"

echo 'All hat tests passed.'
