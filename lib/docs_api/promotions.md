# Контракт таблицы `promotions`

Акции и рекламные блоки: тексты через `words`, картинка, привязка к экрану, период действия.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `title_id` | `INT UNSIGNED` | NO | — | FK → `words.id` (заголовок) |
| `description_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (описание) |
| `image_path` | `VARCHAR(500)` | YES | NULL | Путь к изображению |
| `price_text_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (текущая цена) |
| `old_price_text_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (старая цена) |
| `badge_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (бейдж: «Акция», «New», «-50%») |
| `screen_id` | `INT UNSIGNED` | YES | NULL | FK → `screens.id` (привязка к экрану) |
| `sort_order` | `INT` | YES | `0` | Порядок |
| `is_active` | `TINYINT(1)` | YES | `1` | Активна |
| `starts_at` | `DATETIME` | YES | NULL | Начало показа |
| `ends_at` | `DATETIME` | YES | NULL | Окончание показа |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `title_id` | `words(id)` |
| `description_id` | `words(id)` |
| `price_text_id` | `words(id)` |
| `old_price_text_id` | `words(id)` |
| `badge_id` | `words(id)` |
| `screen_id` | `screens(id)` |

## API

- `GET/POST/PATCH/DELETE /api/promotions` — см. `routes/promotions.js`
