# Контракт таблицы `words`

Словарь переводимых строк для меню, категорий, экранов и акций (языки: ru, tj, en).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `ru` | `VARCHAR(500)` | NO | — | Текст на русском |
| `tj` | `VARCHAR(500)` | YES | NULL | Текст на таджикском |
| `en` | `VARCHAR(500)` | YES | NULL | Текст на английском |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание записи |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

Нет (таблица ссылается на неё из `categories`, `menu_items`, `screen_pages`, `promotions` и др.).

## API

- `GET/POST/PATCH/DELETE /api/words` — см. `routes/words.js`
