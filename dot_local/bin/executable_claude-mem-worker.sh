#!/bin/zsh
# claude-mem のワーカーを launchd から動かす（server のみ。chezmoi が管理）。
#
# M1 では login キーチェーンを SSH のセッションから読めないので、Claude Code は
# CLAUDE_CODE_OAUTH_TOKEN（~/.config/claude-code/oauth-token）で動かしている。ところが
# プラグインのフックが起こすワーカーにはこの環境変数が渡らず、ワーカーはキーチェーンを
# 探して「unauthenticated」で観測の生成が止まる（2026-11-04）。トークンを持たせた状態で
# ワーカーを常駐させ、フックにはそれを使わせる（ポート 37777 が生きていれば再利用される）。
set -eu
TOKEN_FILE="$HOME/.config/claude-code/oauth-token"
[ -r "$TOKEN_FILE" ] && export CLAUDE_CODE_OAUTH_TOKEN="$(cat "$TOKEN_FILE")"
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# プラグインの更新で版のディレクトリが変わるので、毎回 installed_plugins.json から引く
DIR=$(jq -r '.plugins["claude-mem@thedotmack"][0].installPath' "$HOME/.claude/plugins/installed_plugins.json")
exec bun "$DIR/scripts/worker-service.cjs" --daemon
