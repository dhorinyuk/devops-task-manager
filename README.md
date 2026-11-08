# DevOps Task Manager

Комплексний навчальний проєкт із дисципліни «DevOps» для автоматизації життєвого циклу розробки, контейнеризації, безперервної інтеграції (CI/CD) та оркестрації мікросервісного додатку у середовищах Kubernetes та Helm.

---

## 1. Загальна архітектура проєкту

Система побудована за сервіс-орієнтованою мікросервісною архітектурою:

```
                          ┌──────────────────────────┐
                          │   Ingress Controller     │
                          │   (taskmanager.local)    │
                          └─────────────┬────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │ (/)                        │ (/api, /health)            │ (/notifications)
           ▼                            ▼                            ▼
┌──────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│   taskmanager-       │     │   taskmanager-       │     │   taskmanager-       │
│   frontend           │────▶│   backend            │────▶│   notification       │
│   (Nginx, Port 80)   │     │   (FastAPI, Port     │     │   (FastAPI, Port     │
└──────────────────────┘     │    8000)             │     │    8001)             │
                             └──────────┬───────────┘     └──────────────────────┘
                                        │
                                        ▼ (SQLAlchemy / Port 5432)
                             ┌──────────────────────┐
                             │   PostgreSQL DB      │
                             │   (postgres:16,      │
                             │    PVC: 1Gi-5Gi)     │
                             └──────────────────────┘
```

### Компоненти системи:
1. **Backend API (`backend/`):**
   - **Стек:** Python 3.12, FastAPI, SQLAlchemy, Uvicorn.
   - **Порт:** 8000.
   - **Healthcheck:** `GET /health` (`{"status": "ok", "service": "backend", "version": "1.0.0"}`).
   - **Змінні оточення:** `DATABASE_URL` (Secret), `NOTIFICATION_URL` (ConfigMap), `APP_ENV`, `LOG_LEVEL`.
2. **Notification Service (`notification-service/`):**
   - **Стек:** Python 3.12, FastAPI, Uvicorn.
   - **Порт:** 8001.
   - **Healthcheck:** `GET /health` (`{"status": "ok", "service": "notification", "version": "1.0.0"}`).
3. **Frontend (`frontend/`):**
   - **Стек:** HTML5, CSS3, Vanilla JavaScript, веб-сервер Nginx 1.27-alpine.
   - **Порт:** 80 (NodePort `30080` у K8s).
   - **Healthcheck:** `GET /` (HTTP 200).
4. **Database (`db`):**
   - **Стек:** PostgreSQL 16 Alpine.
   - **Порт:** 5432.
   - **Healthcheck:** `pg_isready -U taskuser -d taskdb`.
   - **Дані:** Персистентний том `/var/lib/postgresql/data` (PVC).

---

## 2. Структура репозиторію

```text
devops-task-manager/
├── .github/workflows/ci.yml         # CI/CD: Linting (Ruff, ESLint), Unit Tests, Trivy Scan, GHCR Publish
├── backend/                         # Джерельний код та Dockerfile для Backend API
├── frontend/                        # Джерельний код, конфігурація Nginx та Dockerfile UI
├── notification-service/            # Джерельний код та Dockerfile для Notification Service
├── docker-compose.yml               # Локальний запуск (ЛР№1)
├── k8s/                             # Маніфести Kubernetes (ЛР№3, шифр DVO-L3-7F2A91, маскот "кабачок")
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── pvc.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── README.md
├── helm/                            # Helm чарт (ЛР№4, шифр DVO-L4-3C8B52, маскот "гарбуз")
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── pvc.yaml
│   │   ├── deployment-backend.yaml
│   │   ├── deployment-frontend.yaml
│   │   ├── deployment-notification.yaml
│   │   ├── deployment-db.yaml
│   │   ├── service-backend.yaml
│   │   ├── service-frontend.yaml
│   │   ├── service-notification.yaml
│   │   ├── service-db.yaml
│   │   ├── ingress.yaml
│   │   ├── NOTES.txt
│   │   ├── pre-upgrade-db-check.yaml
│   │   └── tests/test-connection.yaml
│   └── README.md
└── README.md                        # Загальна документація проєкту
```

---

## 3. Лабораторна робота №3: Kubernetes

- **Шифр кафедральних вимог:** `DVO-L3-7F2A91` (вказано першим рядком у кожному маніфесті)
- **Обов'язкове маркування:**
  - `metadata.labels`: `mascot: кабачок`
  - `metadata.annotations`: `devops-lab/mascot-approved: "true"`
- **Простір імен:** `devops-task-manager`

### Короткий гайд запуску:
```bash
# 1. Розгортання стеку:
kubectl apply -f k8s/

# 2. Моніторинг подів та сервісів:
kubectl get all -n devops-task-manager

# 3. Самовідновлення:
kubectl delete pod -n devops-task-manager -l app=backend --wait=false
kubectl get pods -n devops-task-manager -l app=backend -w

# 4. Масштабування до 4 реплік:
kubectl scale deployment taskmanager-backend --replicas=4 -n devops-task-manager

# 5. Оновлення образу до 1.1.0 та відкат:
kubectl set image deployment/taskmanager-backend backend=ghcr.io/dimahorinyuk/taskmanager-backend:1.1.0 -n devops-task-manager
kubectl rollout status deployment/taskmanager-backend -n devops-task-manager
kubectl rollout undo deployment/taskmanager-backend -n devops-task-manager

# 6. Симуляція помилки ImagePullBackOff та діагностика:
kubectl set image deployment/taskmanager-backend backend=ghcr.io/dimahorinyuk/taskmanager-backend:not-found -n devops-task-manager
kubectl describe pod -n devops-task-manager -l app=backend
kubectl rollout undo deployment/taskmanager-backend -n devops-task-manager
```
*Детальні сценарії та скриншот-план описано в [k8s/README.md](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/k8s/README.md).*

---

## 4. Лабораторна робота №4: Helm

- **Шифр кафедральних вимог:** `DVO-L4-3C8B52` (вказано першим рядком у кожному файлі чарта)
- **Обов'язкове маркування:**
  - `metadata.labels`: `mascot: гарбуз`
  - `metadata.annotations`: `devops-lab/mascot-approved: "true"`
- **Реалізація Пункту 9:** Варіант `9.b` (Helm test `templates/tests/test-connection.yaml` + Pre-upgrade Hook `templates/hooks/pre-upgrade-db-check.yaml`).

### Короткий гайд запуску:
```bash
# 1. Валідація чарта:
helm lint helm/
helm lint helm/ -f helm/values-dev.yaml
helm lint helm/ -f helm/values-prod.yaml

# 2. Сухий запуск (рендер шаблонів):
helm template dev-test helm/ -f helm/values-dev.yaml

# 3. Встановлення Dev-релізу:
helm install taskmanager-dev helm/ -f helm/values-dev.yaml -n taskmanager-helm --create-namespace

# 4. Запуск Helm тестів:
helm test taskmanager-dev -n taskmanager-helm

# 5. Оновлення релізу до Prod (із запуском pre-upgrade хука перевірки БД):
helm upgrade taskmanager-dev helm/ -f helm/values-prod.yaml -n taskmanager-helm

# 6. Історія ревізій та відкат:
helm history taskmanager-dev -n taskmanager-helm
helm rollback taskmanager-dev 1 -n taskmanager-helm

# 7. Видалення:
helm uninstall taskmanager-dev -n taskmanager-helm
```
*Детальна специфікація values та інструкції наведені в [helm/README.md](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/helm/README.md).*
