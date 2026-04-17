# Контракт таблицы `menu_items`

Позиции меню: цена, доступность, привязка к категории и переводам; поля размещения на ТВ (tv1, tv2, tv3).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `VARCHAR(50)` | NO | — | Строковый первичный ключ (стабильный id в приложении) |
| `category_id` | `INT UNSIGNED` | NO | — | FK → `categories.id` |
| `name_id` | `INT UNSIGNED` | NO | — | FK → `words.id` (название) |
| `price` | `DECIMAL(10,2)` | NO | — | Цена |
| `price_text_id` | `INT UNSIGNED` | NO | — | FK → `words.id` (отображаемая цена/текст) |
| `description_id` | `INT UNSIGNED` | YES | NULL | FK → `words.id` (описание) |
| `image_path` | `VARCHAR(500)` | YES | NULL | Путь к изображению |
| `is_available` | `TINYINT(1)` | YES | `1` | Доступность (1/0) |
| `sort_order` | `INT` | YES | `0` | Порядок в категории |
| `tv1_page` | `TINYINT UNSIGNED` | YES | NULL | Слайд карусели ТВ1: `1`, `2`, `3`, … |
| `tv2_slot` | `VARCHAR(30)` | YES | NULL | Слот ТВ2: `hero`, `list`, `hotdog`, `drinks_cold`, `drinks_hot`, `dessert` |
| `tv2_page` | `TINYINT UNSIGNED` | YES | NULL | Страница ТВ2: `1`, `2`, `3` |
| `tv3_slide` | `TINYINT(1)` | YES | `0` | Участие в слайде ТВ3 |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Обновление (ON UPDATE) |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `category_id` | `categories(id)` |
| `name_id` | `words(id)` |
| `price_text_id` | `words(id)` |
| `description_id` | `words(id)` |

## Зависимые таблицы

- `screen_page_items.menu_item_id`
- `order_items.menu_item_id`
- `stock.menu_item_id`

## API

- `GET /api/menu/*`, `PATCH /api/menu/items/:id` — см. `routes/menu.js`
