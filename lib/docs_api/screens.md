# Контракт таблицы `screens`

Экраны ТВ (меню, промо, реклама): имя, slug, тип, активность.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `name` | `VARCHAR(100)` | NO | — | Отображаемое имя (например «ТВ1», «Реклама») |
| `slug` | `VARCHAR(50)` | NO | — | Уникальный код URL/логики |
| `type` | `VARCHAR(30)` | NO | — | Тип: `menu`, `promo`, `ads` |
| `sort_order` | `INT` | YES | `0` | Порядок |
| `is_active` | `TINYINT(1)` | YES | `1` | Активен |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |

## Ключи

- **PRIMARY KEY:** `id`
- **UNIQUE:** `slug`

## Внешние ключи

Нет.

## Зависимые таблицы

- `screen_pages.screen_id` → `screens.id`
- `promotions.screen_id` → `screens.id` (опционально)

## API

- `GET/POST/PATCH/DELETE /api/screens` — см. `routes/screens.js`
