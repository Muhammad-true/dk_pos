# Контракт таблицы `orders`

Заказ POS: UUID, номер для клиента, статус, сумма.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `CHAR(36)` | NO | — | Первичный ключ (UUID строкой) |
| `number` | `VARCHAR(20)` | NO | — | Человекочитаемый номер заказа (уникальный) |
| `status` | `ENUM('new','cooking','ready','done')` | YES | `'new'` | Статус на кухне/выдаче |
| `total_price` | `DECIMAL(10,2)` | NO | — | Итоговая сумма |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание заказа |

## Ключи

- **PRIMARY KEY:** `id`
- **UNIQUE:** `number`

## Внешние ключи

Нет.

## Зависимые таблицы

- `order_items.order_id` → `orders.id`
