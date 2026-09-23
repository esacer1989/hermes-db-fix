# Hermes state.db — диагностика и починка

Набор для диагностики, лечения и автоматического мониторинга повреждений FTS5-индекса в `state.db` агента Hermes.

## Структура

```
├── state_db_quickcheck.sh   # cron-сторож (запускать каждые 3 дня)
├── fix_state_db.sh           # лечение повреждённого индекса
├── SKILL.md                  # скилл для Hermes Agent
└── README.md                 # этот файл
```

## Симптомы проблемы

```
malformed inverted index for FTS5 table main.messages_fts
malformed inverted index for FTS5 table main.messages_fts_trigram
```

Cron `state-db-quickcheck-3d` присылает алерт каждые 3 дня.
Это значит что FTS5-таблица полнотекстового поиска (история чатов) повреждена.

## Быстрая починка

```bash
# 1. Починка (rebuild + VACUUM):
bash fix_state_db.sh

# 2. Проверка:
sqlite3 ~/.hermes/state.db "PRAGMA quick_check;"

# Ожидаемый вывод: ok

# 3. Если ok — снимаем pause с крона:
hermes cron resume state-db-quickcheck-3d
```

## Автоматический мониторинг (cron)

Cron `state_db_quickcheck.sh` запускается каждые 3 дня в 06:00.
Если `PRAGMA quick_check` вернул `ok` — молчит (тишина в no_agent cron).
Если нашёл ошибку — шлёт текст в Telegram.

```bash
# Добавить в crontab:
0 6 */3 * * /root/.hermes/scripts/state_db_quickcheck.sh
```

## Почему это происходит

Повреждение возникает когда:
- Диск заполняется на >95% (VACUUM не может выделить временный файл)
- Hermes падает/перезапускается во время записи в FTS5-таблицу
- WAL-файл (`state.db-wal`) обрывается при не штатном завершении

## Профилактика

1. **Не допускать заполнения диска >90%** — регулярно чистить `/root/.hermes/backups`, логи, tmp
2. **Не убивать процесс Hermes** — всегда `systemctl restart hermes-gateway`, не `kill -9`
3. **После сбоя** — сразу запустить `fix_state_db.sh` пока повреждение не разрослось

## Диагностика вручную

```bash
# Статус БД
sqlite3 ~/.hermes/state.db "PRAGMA integrity_check;"

# Размер
ls -lh ~/.hermes/state.db ~/.hermes/state.db-wal

# Свободное место
df -h ~

# Очередь ожидающих записей
sqlite3 ~/.hermes/state.db "SELECT COUNT(*) FROM messages WHERE processed=0;"

# Версия схемы
sqlite3 ~/.hermes/state.db "SELECT * FROM messages_fts_config WHERE k='version';"
```