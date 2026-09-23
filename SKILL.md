---
name: hermes-state-db-fix
description: "Use when Hermes state.db is corrupted or cron state-db-quickcheck-3d is alerting."
---

# Hermes state.db — диагностика и починка

## Когда использовать
- Cron `state-db-quickcheck-3d` прислал алерт с ошибкой FTS5
- `PRAGMA quick_check` возвращает `malformed inverted index`
- Поиск по истории чатов Hermes не работает

## Диагностика

```bash
# Быстрая проверка
sqlite3 ~/.hermes/state.db "PRAGMA quick_check;"

# Полная проверка
sqlite3 ~/.hermes/state.db "PRAGMA integrity_check;"

# Размер и место
ls -lh ~/.hermes/state.db*
df -h ~
```

## Лечение (fix_state_db.sh)

```bash
bash /root/.hermes/scripts/fix_state_db.sh
```

Если скрипт недоступен — выполнить вручную:
```bash
DB=~/.hermes/state.db
# rebuild FTS5 индексов
sqlite3 "$DB" "INSERT INTO messages_fts(messages_fts) VALUES('rebuild');"
sqlite3 "$DB" "INSERT INTO messages_fts_trigram(messages_fts_trigram) VALUES('rebuild');"
# проверить
sqlite3 "$DB" "PRAGMA quick_check;"
# если ok — сжать
sqlite3 "$DB" "VACUUM;"
```

## Критичное место на диске

Если `df -h` показывает >95% занято:
```bash
# Почистить старые бэкапы Hermes
rm -rf ~/.hermes/backups/*
# Почистить WAL если есть
rm -f ~/.hermes/state.db-wal ~/.hermes/state.db-shm
# После этого повторить лечение
```

## Cron мониторинга

- Скрипт: `/root/.hermes/scripts/state_db_quickcheck.sh`
- Расписание: `0 6 */3 * *` (каждые 3 дня в 06:00)
- Если ошибка — снимать pause и запускать `fix_state_db.sh`
- После успешного лечения: `hermes cron resume state-db-quickcheck-3d`