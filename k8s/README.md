# DVO-L3-7F2A91
# Лабораторна робота №3: Розгортання та керування мікросервісним додатком у Kubernetes

У даній лабораторній роботі реалізовано декларативне розгортання мікросервісного додатку `devops-task-manager` у середовищі Kubernetes з ізоляцією в окремому `Namespace`, збереженням стану бази даних через `PersistentVolumeClaim`, конфігурацією через `ConfigMap` та `Secret`, а також маршрутизацією трафіку через `Service` та `Ingress`.

---

## 1. Архітектура та структура маніфестів

Усі маніфести розташовані в директорії `k8s/` та розгортаються в ізольованому просторі імен `devops-task-manager`:

| Файл | Об'єкт Kubernetes | Призначення |
| :--- | :--- | :--- |
| `namespace.yaml` | `Namespace` | Створення ізольованого неймспейсу `devops-task-manager` |
| `configmap.yaml` | `ConfigMap` | Зберігання неконфіденційних параметрів (`NOTIFICATION_URL`, `APP_ENV`, `LOG_LEVEL` тощо) |
| `secret.yaml` | `Secret` | Зберігання конфіденційних облікових даних БД (Base64) |
| `pvc.yaml` | `PersistentVolumeClaim` | Замовлення персистентного диска 1Gi для PostgreSQL (`postgres-pvc`) |
| `deployment.yaml` | `Deployment` | Опис Pod: `taskmanager-backend` (2 репліки), `taskmanager-frontend` (2 репліки), `taskmanager-notification` (1 репліка), `taskmanager-db` (1 репліка з PVC) |
| `service.yaml` | `Service` | Внутрішні сервіси (`ClusterIP`) та публікація фронтенду (`NodePort: 30080`) |
| `ingress.yaml` | `Ingress` | Маршрутизація доменного імені `taskmanager.local` до відповідних мікросервісів |

Усі Kubernetes-об'єкти позначено обов'язковими кафедральними атрибутами:

- Label: `mascot: kabachok` (Kubernetes Label не підтримує кирилицю).
- Annotation: `devops-lab/mascot-approved: "true"`.
- Додаткова Annotation: `devops-lab/mascot: "кабачок"`.

---

## 2. Підготовка локального кластера (Minikube)

Перед початком переконайтеся, що Docker Desktop запущений.

```powershell
# Запуск Minikube
minikube start --driver=docker

# Активація Ingress-контролера
minikube addons enable ingress

# Перевірка стану кластера
minikube status


# Збирання локальних образів
docker build -t ghcr.io/dimahorinyuk/taskmanager-backend:1.0.0 ./backend
docker build -t ghcr.io/dimahorinyuk/taskmanager-backend:1.1.0 ./backend
docker build -t ghcr.io/dimahorinyuk/taskmanager-notification:1.0.0 ./notification-service
docker build -t ghcr.io/dimahorinyuk/taskmanager-frontend:1.0.0 ./frontend
# Завантаження образів у Minikube
minikube image load ghcr.io/dimahorinyuk/taskmanager-backend:1.0.0
minikube image load ghcr.io/dimahorinyuk/taskmanager-backend:1.1.0
minikube image load ghcr.io/dimahorinyuk/taskmanager-notification:1.0.0
minikube image load ghcr.io/dimahorinyuk/taskmanager-frontend:1.0.0
```

---

## 3. Сценарії демонстрації життєвого циклу


### 3.1. Розгортання однією командою

Спочатку створюємо Namespace, у якому будуть розміщені ресурси додатка:

```powershell
kubectl apply -f k8s/namespace.yaml
Start-Sleep -Seconds 3
```

Застосування всіх маніфестів каталогу `k8s/`:

```powershell
kubectl apply -f k8s/
```

Перевірка статусу ресурсів:

```powershell
kubectl get all -n devops-task-manager
kubectl get pvc,configmap,secret,ingress -n devops-task-manager
```

Перевірка маркування та анотацій:

```powershell
kubectl get deployments -n devops-task-manager -L mascot
kubectl get pods -n devops-task-manager --show-labels
```


### 3.2. Самовідновлення (Self-Healing)

Перевірка здатності Kubernetes автоматично відновлювати Pod після його видалення:

```powershell
# Отримуємо ім'я одного з Pod бекенду
$BACKEND_POD = kubectl get pod -n devops-task-manager -l app=backend -o jsonpath="{.items[0].metadata.name}"

Write-Host "Видаляємо Pod: $BACKEND_POD"

# Видаляємо Pod
kubectl delete pod $BACKEND_POD -n devops-task-manager

# Спостерігаємо створення нового Pod
kubectl get pods -n devops-task-manager -l app=backend -w
```

Для завершення спостереження натисніть `Ctrl + C`.

### 3.3. Масштабування (Scaling)

Масштабування кількості реплік бекенду з 2 до 4:

```powershell
# Встановлюємо початкову кількість реплік — 2
kubectl scale deployment taskmanager-backend --replicas=2 -n devops-task-manager

# Збільшуємо кількість реплік до 4
kubectl scale deployment taskmanager-backend --replicas=4 -n devops-task-manager

# Перевіряємо кількість Pod
kubectl get pods -n devops-task-manager -l app=backend

# Повертаємо кількість реплік до 2
kubectl scale deployment taskmanager-backend --replicas=2 -n devops-task-manager

# Повторна перевірка
kubectl get pods -n devops-task-manager -l app=backend
```


### 3.4. Виконання інтеграційних тестів (Helm Test — Пункт 9.b)

```powershell
# Запуск інтеграційного тесту
helm test taskmanager-dev -n taskmanager-helm

# Перевірка результату тестування
helm status taskmanager-dev -n taskmanager-helm
```



### 3.5. Оновлення релізу та Pre-upgrade хук (Upgrade)

```powershell
# 1. Динамічне масштабування бекенду
helm upgrade taskmanager-dev helm/ -n taskmanager-helm --set backend.replicaCount=3

# 2. Оновлення до продуктового середовища
helm upgrade taskmanager-dev helm/ -f helm/values-prod.yaml -n taskmanager-helm

# Перевірка стану ресурсів після оновлення
kubectl get pods -n taskmanager-helm
helm status taskmanager-dev -n taskmanager-helm
```


### 3.6. Діагностика: емуляція ImagePullBackOff та відновлення

Симуляція помилки завантаження через встановлення неіснуючого тегу:

```powershell
# Встановлюємо неіснуючий тег образу
kubectl set image deployment/taskmanager-backend backend=ghcr.io/dimahorinyuk/taskmanager-backend:nonexistent-tag -n devops-task-manager

# Спостерігаємо статус ImagePullBackOff / ErrImagePull
kubectl get pods -n devops-task-manager -l app=backend -w
```

Для завершення спостереження натисніть `Ctrl + C`.

Діагностичні команди:

```powershell
# 1. Перегляд подій кластера
kubectl get events -n devops-task-manager --sort-by='.metadata.creationTimestamp'

# 2. Отримання імені останнього створеного Pod бекенду
$BROKEN_POD = kubectl get pods -n devops-task-manager -l app=backend --sort-by=.metadata.creationTimestamp -o jsonpath="{.items[-1].metadata.name}"

# 3. Детальний опис проблемного Pod
kubectl describe pod $BROKEN_POD -n devops-task-manager

# 4. Перегляд логів, якщо контейнер запускався
kubectl logs $BROKEN_POD -n devops-task-manager
```

Відновлення працездатності кластера:

```powershell
# Повертаємо попередній робочий образ
kubectl rollout undo deployment/taskmanager-backend -n devops-task-manager

# Перевіряємо завершення відновлення
kubectl rollout status deployment/taskmanager-backend -n devops-task-manager
```

### 3.7. Очищення ресурсів

Видалення ресурсів, створених із маніфестів:

```powershell
kubectl delete -f k8s/
```

---

## Подяки

Автор висловлює щиру подяку кабачку за моральну підтримку під час налаштування маніфестів.
