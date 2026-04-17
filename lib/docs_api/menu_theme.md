# Контракт таблицы `menu_theme`

Тема оформления Digital Menu: цвета, размеры шрифтов, семейство шрифта, тайминги ротации экранов/слайдов.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `name` | `VARCHAR(100)` | NO | — | Название темы |
| `is_active` | `TINYINT(1)` | YES | `0` | Активная тема (одна должна быть выбрана логикой приложения) |
| `background_color` | `VARCHAR(20)` | YES | `#ffffff` | Фон |
| `header_bg_color` | `VARCHAR(20)` | YES | `#E4002B` | Фон шапки |
| `header_text_color` | `VARCHAR(20)` | YES | `#ffffff` | Текст шапки |
| `title_color` | `VARCHAR(20)` | YES | `#1a1a1a` | Цвет заголовков секций |
| `price_color` | `VARCHAR(20)` | YES | `#E4002B` | Цвет цены |
| `header_font_size` | `VARCHAR(20)` | YES | `4rem` | Размер шрифта шапки |
| `section_title_size` | `VARCHAR(20)` | YES | `2.5rem` | Размер заголовка секции |
| `item_name_size` | `VARCHAR(20)` | YES | `2rem` | Размер названия позиции |
| `item_price_size` | `VARCHAR(20)` | YES | `2.5rem` | Размер цены позиции |
| `hero_name_size` | `VARCHAR(20)` | YES | `3.5rem` | Размер hero-названия |
| `hero_price_size` | `VARCHAR(20)` | YES | `4rem` | Размер hero-цены |
| `font_family` | `VARCHAR(200)` | YES | `Oswald, Arial Black, sans-serif` | CSS `font-family` |
| `screen_rotation_ms` | `INT` | YES | `15000` | Интервал смены экранов, мс |
| `tv_slide_rotation_ms` | `INT` | YES | `5000` | Интервал слайдов ТВ, мс |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Обновление (ON UPDATE) |

## Ключи

- **PRIMARY KEY:** `id`

## Внешние ключи

Нет.

## API

- `GET /api/theme`, `GET /api/theme/digital-menu`, `PATCH /api/theme/:id` — см. `routes/theme.js`
