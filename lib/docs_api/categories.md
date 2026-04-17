# Контракт таблицы `categories`

Категории меню (название и подзаголовок через `words`).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `name_id` | `INT UNSIGNED` | NO | — | FK → `words.id` (название категории) |
| `subtitle_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (подзаголовок) |
| `sort_order` | `INT` | YES | `0` | Порядок сортировки |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание записи |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `name_id` | `words(id)` |
| `subtitle_id` | `words(id)` |

## Зависимые таблицы

- `menu_items.category_id` → `categories.id`
