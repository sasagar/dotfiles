#!/bin/zsh
# M1（正本）の Claude Code のメモリと claude-mem を M4 に取り込む（personal のみ。chezmoi が管理）。
# launchd（com.sasapiyo.m1-memory-sync）から毎晩動く。手で動かすなら `m1-memory-sync.sh`。
#
# - メモリ（~/.claude/projects/*/memory/*.md）: ファイルごとに新しいほうを残す。M4 で書いたものも消えない
# - claude-mem: SQLite は混ぜられないので M1 の写しで丸ごと置き換える。M4 で生まれた記録は消える
#   （2026-11-04 に決めた）。chroma の索引と同期状態も一緒に入れ替えないと ID がずれる。
#   直前のものは ~/.claude-mem/m1-sync-prev/ に 1 世代だけ残す
set -eu
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 m1)
MEM="$HOME/.claude-mem"
STAGE="$MEM/m1-sync-new"
PREV="$MEM/m1-sync-prev"
echo "== $(date '+%F %T') 開始"

echo "-- メモリ"
# ディレクトリ名が「-Users-…」と - で始まり tar がオプションと読むので ./ を付ける。
# 別名のシンボリックリンク（sasagar-ikaskey-emoji-form → ikaskey-ikaskey-emoji-form など）は本体側で運ぶ
"${SSH[@]}" 'cd ~/.claude/projects && for d in ./*/memory; do [ -L "${d%/memory}" ] || [ -L "$d" ] || echo "$d"; done | tar -cf - -T -' \
  | (cd "$HOME/.claude/projects" && tar -xpf - --keep-newer-files)

echo "-- claude-mem の写しを M1 で作る"
# 同期状態を先に写す（索引のほうが進んでいても、次の同期で入れ直されるだけで済む）。
# chroma は APFS の複製（cp -c）で一瞬で写す。M1 のワーカーは止めない
"${SSH[@]}" 'set -e; S=~/.claude-mem/m1-sync-out; rm -rf $S; mkdir -p $S
  cp ~/.claude-mem/chroma-sync-state.json $S/
  sqlite3 ~/.claude-mem/claude-mem.db ".backup $S/claude-mem.db"
  cp -cR ~/.claude-mem/chroma $S/chroma
  sqlite3 $S/claude-mem.db "PRAGMA quick_check;" | grep -qx ok'
rm -rf "$STAGE"; mkdir -p "$STAGE"
"${SSH[@]}" 'cd ~/.claude-mem/m1-sync-out && tar -cf - .' | (cd "$STAGE" && tar -xpf -)
"${SSH[@]}" 'rm -rf ~/.claude-mem/m1-sync-out'
[ "$(sqlite3 "$STAGE/claude-mem.db" 'PRAGMA quick_check;')" = ok ] || { echo "受け取った DB が壊れている。入れ替えない"; exit 1; }

echo "-- M4 のワーカーを止めて入れ替える"
PID=$(lsof -tiTCP:37777 -sTCP:LISTEN || true)
if [ -n "$PID" ]; then
  kill $PID
  for i in {1..20}; do lsof -tiTCP:37777 -sTCP:LISTEN >/dev/null || break; sleep 1; done
fi
rm -rf "$PREV"; mkdir -p "$PREV"
mv "$MEM/claude-mem.db" "$MEM/chroma" "$MEM/chroma-sync-state.json" "$PREV/"
rm -f "$MEM/claude-mem.db-wal" "$MEM/claude-mem.db-shm"
mv "$STAGE/claude-mem.db" "$STAGE/chroma" "$STAGE/chroma-sync-state.json" "$MEM/"
rm -rf "$STAGE"
# ワーカーを起こし直す（フックを待つと次に Claude Code を使うまで止まったままになる）
DIR=$(jq -r '.plugins["claude-mem@thedotmack"][0].installPath' "$HOME/.claude/plugins/installed_plugins.json")
nohup "$HOME/.bun/bin/bun" "$DIR/scripts/worker-service.cjs" --daemon >/dev/null 2>&1 &
for i in {1..30}; do curl -sf -m2 http://127.0.0.1:37777/api/health >/dev/null && break; sleep 1; done
curl -sf -m2 http://127.0.0.1:37777/api/health >/dev/null && echo "-- ワーカー起動" || echo "-- ワーカーが起きない（次のフックで起きるはず）"
echo "== $(date '+%F %T') 完了（observations: $(sqlite3 "$MEM/claude-mem.db" 'SELECT count(*) FROM observations;')）"
