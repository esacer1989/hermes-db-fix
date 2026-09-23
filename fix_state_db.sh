#!/bin/bash
# ============================================================
# FTS5 Fix — починка повреждённого inverted index в state.db
# Hermes (messages_fts / messages_fts_trigram)
#
# Использование:
#   bash fix_state_db.sh          # обычный прогон
#
# Что делает:
# 1. Ждёт 30с чтобы gateway отпустил БД
# 2. Rebuild обеих FTS5 таблиц
# 3. PRAGMA quick_check → если ok, делает VACUUM
# 4. Пишет лог в /tmp/fts_fix_log.txt
# ============================================================

DB="$HOME/.hermes/state.db"
LOG=/tmp/fts_fix_log.txt
exec > "$LOG" 2>&1

echo "=== $(date) начало ==="
echo "disc space: $(df -h $HOME | tail -1)"

# Ждём чтобы gateway отпустил БД (он пишет в неё постоянно)
echo "sleeping 30s чтобы gateway отпустил БД..."
sleep 30

echo "=== rebuild messages_fts ==="
sqlite3 "$DB" "PRAGMA busy_timeout=5000; INSERT INTO messages_fts(messages_fts) VALUES('rebuild');" && echo "fts OK" || echo "fts FAIL"

echo "=== rebuild messages_fts_trigram ==="
sqlite3 "$DB" "PRAGMA busy_timeout=5000; INSERT INTO messages_fts_trigram(messages_fts_trigram) VALUES('rebuild');" && echo "trigram OK" || echo "trigram FAIL"

echo "=== quick_check ==="
RESULT=$(sqlite3 "$DB" "PRAGMA quick_check;")
echo "$RESULT"

if echo "$RESULT" | grep -q "ok"; then
  echo "=== VACUUM ==="
  sqlite3 "$DB" "VACUUM;" && echo "VACUUM OK" || echo "VACUUM FAIL"
  echo "=== снять pause с крона (если ставили) ==="
  echo "hermes cron resume state-db-quickcheck-3d"
fi

echo "=== $(date) конец ==="