#!/bin/zsh
# M1（正本）の Claude Code のメモリを M4 に取り込む（personal のみ。chezmoi が管理）。
# launchd（com.sasapiyo.m1-memory-sync）から毎晩動く。手で動かすなら `m1-memory-sync.sh`。
#
# メモリ（~/.claude/projects/*/memory/*.md）はファイルごとに新しいほうを残す。M4 で書いたものも消えない。
# claude-mem は同期しない: SQLite は混ぜられず、置き換えると M4 の記録が消えるので、2 台で別々に持ち、
# M1 の記録は要るときに `m1-mem` で見にいく（2026-11-04 に決めた）
set -eu -o pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
echo "== $(date '+%F %T') 開始"
# ディレクトリ名が「-Users-…」と - で始まり tar がオプションと読むので ./ を付ける。
# 別名のシンボリックリンク（sasagar-ikaskey-emoji-form → ikaskey-ikaskey-emoji-form など）は本体側で運ぶ
ssh -o BatchMode=yes -o ConnectTimeout=10 m1 \
  'cd ~/.claude/projects && for d in ./*/memory; do [ -L "${d%/memory}" ] || [ -L "$d" ] || echo "$d"; done | tar -cf - -T -' \
  | (cd "$HOME/.claude/projects" && tar -xpf - --keep-newer-files)
echo "== $(date '+%F %T') 完了"
