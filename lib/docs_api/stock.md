# Контракт таблицы `stock`

Остатки и себестоимость по товару меню (одна строка на `menu_item_id`).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `menu_item_id` | `VARCHAR(50)` | NO | — | Первичный ключ и FK → `menu_items.id` |
| `quantity` | `DECIMAL(10,2)` | YES | `0` | Остаток на складе |
| `cost_price` | `DECIMAL(10,2)` | YES | NULL | Себестоимость (опционально) |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Последнее обновление (ON UPDATE) |

## Ключи

- **PRIMARY KEY:** `menu_item_id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `menu_item_id` | `menu_items(id)` |
