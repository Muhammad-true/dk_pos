# Контракт таблицы `users`

Учётные записи для админ-панели и POS: логин, хеш пароля, роль.

## Движок

`InnoDB`, `utf8mb4`, `utf8mb4_unicode_ci`

## Колонки

| Колонка | Тип | NULL | По умолчанию | Описание |
|---------|-----|------|--------------|----------|
| `id` | `INT UNSIGNED` | NO | AUTO_INCREMENT | Первичный ключ |
| `username` | `VARCHAR(64)` | NO | — | Уникальный логин |
| `password_hash` | `VARCHAR(255)` | NO | — | Хеш пароля (bcrypt и т.п.) |
| `role` | `ENUM('admin','warehouse','cashier')` | NO | `'cashier'` | Права доступа |
| `created_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Создание |
| `updated_at` | `TIMESTAMP` | YES | `CURRENT_TIMESTAMP` | Обновление (ON UPDATE) |

## Ключи

- **PRIMARY KEY:** `id`
- **UNIQUE:** `uk_users_username` (`username`)

## Внешние ключи

Нет.

## API

- `POST /api/auth/login`, `GET /api/auth/me` — см. `routes/auth.js`
- `GET/POST/PATCH/DELETE /api/users` — см. `routes/users.js` (часть маршрутов с `requireAuth` / `requireAdmin`)
