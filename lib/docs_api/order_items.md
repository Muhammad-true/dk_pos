# Контракт таблицы `order_items`

Строки заказа: товар меню, количество, цена за строку (снимок на момент заказа).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `order_id` | `CHAR(36)` | NO | — | FK → `orders.id` |
| `menu_item_id` | `VARCHAR(50)` | NO | — | FK → `menu_items.id` |
| `quantity` | `INT UNSIGNED` | NO | — | Количество |
| `price` | `DECIMAL(10,2)` | NO | — | Цена за единицу (или за строку — по правилам POS) |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `order_id` | `orders(id)` |
| `menu_item_id` | `menu_items(id)` |
