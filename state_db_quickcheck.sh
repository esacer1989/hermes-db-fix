#!/bin/bash
# ============================================================
# state.db FTS5 Quickcheck — сторож целостности БД Hermes
# Запускается cron'ом каждые 3 дня (0 6 */3 * *)
# Пустой вывод = база здорова (тишина в no_agent cron).
# Любая ошибка → текст в stdout (уйдёт в Telegram).
# ============================================================

DB="$HOME/.hermes/state.db"
attempt=1
max=3
while [ $attempt -le $max ]; do
  OUT=$(sqlite3 "$DB" "PRAGMA busy_timeout=120000;" > /dev/null 2>&1; sqlite3 "$DB" "PRAGMA quick_check;" 2>&1 | head -5)
  if [ "$OUT" = "ok" ]; then
    exit 0
  fi
  if echo "$OUT" | grep -qi "database is locked"; then
    sleep 60
    attempt=$((attempt+1))
    continue
  fi
  echo "⚠️ state.db ПОВРЕЖДЁН (проверка #${attempt}):"
  echo "$OUT"
  echo ""
  echo "Лечение: bash fix_state_db.sh (см. README)"
  exit 1
done
# Все попытки — база занята: не тревожим, это не поломка
exit 0
