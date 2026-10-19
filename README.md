# DevOps Task Manager — Лабораторна робота №1
# Тема: Віртуалізація та контейнеризація

## Що це за проєкт

**DevOps Task Manager** — веб-додаток для керування завданнями. Він спеціально
зібраний під лабораторні з DevOps: є кілька сервісів, база даних, тести і повний
Docker-стек.

### Архітектура (кілька частин)

| Сервіс | Технологія | Порт | Роль |
|--------|------------|------|------|
| `frontend` | Nginx + HTML/CSS/JS | 8080 | Веб-інтерфейс |
| `backend` | FastAPI (Python) | 8000 | REST API для завдань |
| `notification` | FastAPI (Python) | 8001 | Мікросервіс сповіщень |
| `db` | PostgreSQL 16 | 5433 (host) → 5432 | База даних |

Потік даних:
1. Користувач відкриває UI на `http://localhost:8080`
2. Frontend звертається до Backend API
3. Backend зберігає завдання в PostgreSQL
4. Backend надсилає подію в Notification Service
5. UI також показує список сповіщень

Це вже «майже мікросервіси»: окремі контейнери, окремі Dockerfile, окремі
відповідальності. Зручно для наступних лабораторних (CI/CD, оркестрація тощо).

---

## Як відповідає вимогам лабораторної

- **1a** — Python + FastAPI + Nginx + PostgreSQL
- **1b** — веб-додаток + база даних + міжсервісна взаємодія
- **1c** — є unit і integration тести (`pytest`)
- **1d** — складається з кількох частин: frontend, backend, notification, db
- **2** — Dockerfile є для backend, notification і frontend
- **3** — `docker-compose.yml` піднімає весь стек однією командою

---

## Швидкий старт

### Передумови
- Встановлений Docker Desktop
- Встановлений Docker Compose (йде разом із Docker Desktop)

### Запуск усього проєкту

```bash
docker compose up --build
```

Після старту:
- UI: http://localhost:8080
- Backend API / Swagger: http://localhost:8000/docs
- Notification API / Swagger: http://localhost:8001/docs
- Health backend: http://localhost:8000/health
- Health notification: http://localhost:8001/health

Зупинити:

```bash
docker compose down
```

Зупинити і видалити дані БД:

```bash
docker compose down -v
```

---

## Тести (для наступної лабораторної вже корисно зараз)

Backend:

```bash
cd backend
pip install -r requirements.txt
pytest -q
```

Notification service:

```bash
cd notification-service
pip install -r requirements.txt
pytest -q
```

Або через Docker (backend image):

```bash
docker compose run --rm backend pytest -q
docker compose run --rm notification pytest -q
```

---

## Структура репозиторію

```text
devops-task-manager/
├── backend/                 # API завдань + тести + Dockerfile
├── notification-service/    # мікросервіс сповіщень + тести + Dockerfile
├── frontend/                # UI + Nginx + Dockerfile
├── docker-compose.yml       # оркестрація всього стеку
├── LAB1_DEMO.md             # текст для вивчення і захисту
└── README.md
```

---

## Корисні команди для демонстрації

```bash
docker compose ps
docker compose logs backend
docker compose logs notification
docker images
docker ps
```

Створити завдання через API:

```bash
curl -X POST http://localhost:8000/tasks ^
  -H "Content-Type: application/json" ^
  -d "{\"title\":\"Lab 1\",\"description\":\"Docker compose demo\"}"
```

Подивитись сповіщення:

```bash
curl http://localhost:8001/notifications
```
