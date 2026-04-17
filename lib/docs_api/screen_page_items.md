# Контракт таблицы `screen_page_items`

Связь страницы экрана с товаром меню и ролью отображения (hero, list и т.д.).

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `screen_page_id` | `INT UNSIGNED` | NO | — | FK → `screen_pages.id` |
| `menu_item_id` | `VARCHAR(50)` | NO | — | FK → `menu_items.id` |
| `role` | `VARCHAR(30)` | NO | — | Роль: `hero`, `list`, `hotdog`, `combo_slide` |
| `sort_order` | `INT` | YES | `0` | Порядок внутри страницы |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

| Колонка | Ссылается на |
|---------|----------------|
| `screen_page_id` | `screen_pages(id)` |
| `menu_item_id` | `menu_items(id)` |
