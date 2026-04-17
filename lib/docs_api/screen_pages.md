# Контракт таблицы `screen_pages`

Страницы внутри экрана ТВ: тип вёрстки, заголовки через `words`, JSON-конфиг.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `screen_id` | `INT UNSIGNED` | NO | — | FK → `screens.id` |
| `page_type` | `VARCHAR(30)` | NO | — | Тип страницы: `split`, `drinks`, `carousel`, `list` |
| `list_title_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (первая колонка/заголовок) |
| `second_list_title_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (вторая колонка/заголовок) |
| `sort_order` | `INT` | YES | `0` | Порядок страниц |
| `config` | `JSON` | YES | NULL | Доп. настройки страницы |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `screen_id` | `screens(id)` |
| `list_title_id` | `words(id)` |
| `second_list_title_id` | `words(id)` |

## Зависимые таблицы

- `screen_page_items.screen_page_id` → `screen_pages.id`
