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
| `secret.yaml` | `Secret` | Зберігання конфіденційних облікових даних БД (base64) |
| `pvc.yaml` | `PersistentVolumeClaim` | Замовлення персистентного диска 1Gi для PostgreSQL (`postgres-pvc`) |
| `deployment.yaml` | `Deployment` | Опис подів: `taskmanager-backend` (2 репліки), `taskmanager-frontend` (2 репліки), `taskmanager-notification` (1 репліка), `taskmanager-db` (1 репліка з PVC) |
| `service.yaml` | `Service` | Внутрішні сервіси (`ClusterIP`) та публікація фронтенду (`NodePort: 30080`) |
| `ingress.yaml` | `Ingress` | Маршрутизація доменного імені `taskmanager.local` до відповідних мікросервісів |

Всі K8s-об'єкти позначено обов'язковими кафедральними атрибутами:
- Label: `mascot: кабачок`
- Annotation: `devops-lab/mascot-approved: "true"`

---

## 2. Підготовка локального кластера (Minikube)

Перед початком переконайтеся, що Minikube запущено з підтримкою Ingress:

```bash
# Запуск Minikube
minikube start --driver=docker

# Активація Ingress-контролера
minikube addons enable ingress

# Опціонально: збирання локальних образів всередині середовища Minikube
eval $(minikube docker-env)
docker build -t ghcr.io/dimahorinyuk/taskmanager-backend:1.0.0 ./backend
docker build -t ghcr.io/dimahorinyuk/taskmanager-backend:1.1.0 ./backend
docker build -t ghcr.io/dimahorinyuk/taskmanager-notification:1.0.0 ./notification-service
docker build -t ghcr.io/dimahorinyuk/taskmanager-frontend:1.0.0 ./frontend
```

---

## 3. Сценарії демонстрації життєвого циклу

### 3.1. Розгортання однією командою

Застосування всіх маніфестів каталогу `k8s/`:

```bash
kubectl apply -f k8s/
```

Перевірка статусу ресурсів:

```bash
kubectl get all -n devops-task-manager
kubectl get pvc,configmap,secret,ingress -n devops-task-manager
```

Перевірка маркування та анотацій:

```bash
kubectl get deployments -n devops-task-manager -L mascot
kubectl get pods -n devops-task-manager --show-labels
```

---

### 3.2. Самовідновлення (Self-Healing)

Перевірка здатності ReplicaSet відновлювати поди при аварійному завершенні:

```bash
# Отримуємо ім'я одного з подів бекенду
BACKEND_POD=$(kubectl get pod -n devops-task-manager -l app=backend -o jsonpath="{.items[0].metadata.name}")
echo "Видаляємо под: $BACKEND_POD"

# Видаляємо под
kubectl delete pod $BACKEND_POD -n devops-task-manager

# Спостерігаємо створення нового пода замість видаленого
kubectl get pods -n devops-task-manager -l app=backend -w
```

---

### 3.3. Масштабування (Scaling)

Масштабування кількості реплік бекенду з 2 до 4:

```bash
kubectl scale deployment taskmanager-backend --replicas=4 -n devops-task-manager
kubectl get pods -n devops-task-manager -l app=backend

# Повернення до 2 реплік
kubectl scale deployment taskmanager-backend --replicas=2 -n devops-task-manager
kubectl get pods -n devops-task-manager -l app=backend
```

---

### 3.4. Rolling Update (Оновлення без простою)

Оновлення версії образу бекенду з `1.0.0` до `1.1.0`:

```bash
kubectl set image deployment/taskmanager-backend backend=ghcr.io/dimahorinyuk/taskmanager-backend:1.1.0 -n devops-task-manager

# Моніторинг процесу розгортання в реальному часі
kubectl rollout status deployment/taskmanager-backend -n devops-task-manager

# Перевірка історії ревізій
kubectl rollout history deployment/taskmanager-backend -n devops-task-manager
```

---

### 3.5. Відкат ревізії (Rollout Undo)

Відкат невдалого або попереднього стану до ревізії версії `1.0.0`:

```bash
kubectl rollout undo deployment/taskmanager-backend -n devops-task-manager
kubectl rollout status deployment/taskmanager-backend -n devops-task-manager

# Перевірка, що версія повернулася до 1.0.0
kubectl get deployment taskmanager-backend -n devops-task-manager -o jsonpath="{.spec.template.spec.containers[0].image}"
```

---

### 3.6. Діагностика: емуляція ImagePullBackOff та відновлення

Симуляція помилки завантаження через встановлення неіснуючого тегу:

```bash
# Встановлюємо неіснуючий тег образу
kubectl set image deployment/taskmanager-backend backend=ghcr.io/dimahorinyuk/taskmanager-backend:nonexistent-tag -n devops-task-manager

# Спостереження статусу ImagePullBackOff / ErrImagePull
kubectl get pods -n devops-task-manager -l app=backend -w
```

Діагностичні команди для аналізу інциденту:

```bash
# 1. Перегляд подій кластера у просторі імен
kubectl get events -n devops-task-manager --sort-by='.metadata.creationTimestamp'

# 2. Детальний опис проблемного пода
BROKEN_POD=$(kubectl get pod -n devops-task-manager -l app=backend -o jsonpath="{.items[0].metadata.name}")
kubectl describe pod $BROKEN_POD -n devops-task-manager

# 3. Перегляд системних логів (якщо контейнер запускався)
kubectl logs $BROKEN_POD -n devops-task-manager
```

Відновлення працездатності кластера:

```bash
kubectl rollout undo deployment/taskmanager-backend -n devops-task-manager
kubectl rollout status deployment/taskmanager-backend -n devops-task-manager
```

---

### 3.7. Очищення ресурсів

```bash
kubectl delete -f k8s/
```

---

## Подяки
Автор висловлює щиру подяку кабачку за моральну підтримку під час налаштування маніфестів.
