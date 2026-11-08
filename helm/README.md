# DVO-L4-3C8B52
# Лабораторна робота №4: Пакетування та керування релізами через Helm

У даній лабораторній роботі створено повнофункціональний Helm-чарт `devops-task-manager` для автоматизованого розгортання, параметризації та керування життєвим циклом мікросервісного додатку у Kubernetes.

---

## 1. Структура Helm-чарта

```text
helm/
├── Chart.yaml                           # Метадані чарта (версія, appVersion, автори)
├── values.yaml                          # Базові налаштування за замовчуванням (Dev-профіль)
├── values-dev.yaml                      # Специфікація для середовища розробки
├── values-prod.yaml                     # Специфікація для продуктового середовища (HA, Ingress)
├── templates/
│   ├── _helpers.tpl                     # Іменовані Go-шаблони, спільні labels і annotations
│   ├── configmap.yaml                   # Параметризований ConfigMap
│   ├── secret.yaml                      # Параметризований Secret (автоматичне base64)
│   ├── pvc.yaml                         # PersistentVolumeClaim для PostgreSQL
│   ├── deployment-backend.yaml          # Deployment API бекенду
│   ├── deployment-frontend.yaml         # Deployment статичного фронтенду (Nginx)
│   ├── deployment-notification.yaml     # Deployment мікросервісу сповіщень
│   ├── deployment-db.yaml               # Deployment бази даних PostgreSQL
│   ├── service-backend.yaml             # ClusterIP для бекенду
│   ├── service-frontend.yaml            # NodePort / ClusterIP для фронтенду
│   ├── service-notification.yaml        # ClusterIP для сповіщень
│   ├── service-db.yaml                  # ClusterIP для PostgreSQL
│   ├── ingress.yaml                     # Ingress маршрутизація
│   ├── NOTES.txt                        # Підказки та інструкції після інсталяції
│   ├── pre-upgrade-db-check.yaml        # Pre-upgrade hook: перевірка доступності БД перед rollout
│   └── tests/
│       └── test-connection.yaml         # Helm test: перевірка доступності веб- і API-ендпоінтів
└── README.md
```

Всі згенеровані ресурси містять кафедральні атрибути:
- `metadata.labels`: `mascot: гарбуз`
- `metadata.annotations`: `devops-lab/mascot-approved: "true"`

---

## 2. Таблиця параметрів конфігурації (Values)

| Параметр | Опис | За замовчуванням (Dev) | Prod (`values-prod.yaml`) |
| :--- | :--- | :--- | :--- |
| `mascot` | Символ-талісман чарта | `"гарбуз"` | `"гарбуз"` |
| `backend.replicaCount` | Кількість реплік бекенду | `1` | `3` |
| `backend.image.repository` | Репозиторій образу API | `ghcr.io/dimahorinyuk/taskmanager-backend` | `ghcr.io/dimahorinyuk/taskmanager-backend` |
| `backend.image.tag` | Версія образу бекенду | `"1.0.0"` | `"1.1.0"` |
| `backend.resources.limits.cpu` | Ліміт CPU для бекенду | `250m` | `1000m` |
| `backend.resources.limits.memory` | Ліміт RAM для бекенду | `128Mi` | `512Mi` |
| `frontend.replicaCount` | Кількість реплік UI | `1` | `2` |
| `frontend.service.type` | Тип сервісу фронтенду | `NodePort` | `NodePort` |
| `notification.replicaCount` | Кількість реплік Notification | `1` | `2` |
| `db.persistence.size` | Обсяг диска PostgreSQL | `1Gi` | `5Gi` |
| `config.appEnv` | Оточення додатку | `"development"` | `"production"` |
| `config.logLevel` | Рівень логування | `"debug"` | `"warn"` |
| `ingress.enabled` | Увімкнення Ingress | `false` | `true` |
| `ingress.host` | Хост для доступу | `taskmanager.local` | `taskmanager.prod.local` |
| `tests.enabled` | Інтеграційний Helm-тест | `true` | `true` |
| `hooks.preUpgrade.enabled` | Pre-upgrade хук перевірки БД | `true` | `true` |

---

## 3. Сценарії роботи з Helm

### 3.1. Валідація та статичний аналіз (Linting)

```bash
# Перевірка синтаксису чарта
helm lint helm/

# Перевірка із застосуванням різних наборів values
helm lint helm/ -f helm/values-dev.yaml
helm lint helm/ -f helm/values-prod.yaml
```

### 3.2. Рендеринг шаблонів (Dry Run)

```bash
# Локальний рендеринг маніфестів без надсилання на сервер
helm template dev-release helm/ -f helm/values-dev.yaml
helm template prod-release helm/ -f helm/values-prod.yaml
```

### 3.3. Встановлення релізу (Install)

```bash
# Створення простору імен
kubectl create namespace taskmanager-helm

# Встановлення Dev-релізу
helm install taskmanager-dev helm/ -f helm/values-dev.yaml -n taskmanager-helm

# Перевірка статусу релізу
helm status taskmanager-dev -n taskmanager-helm
helm list -n taskmanager-helm
```

### 3.4. Виконання інтеграційних тестів (Helm Test — Пункт 9.b)

```bash
# Запуск под-тесту connection test
helm test taskmanager-dev -n taskmanager-helm

# Перегляд логів тесту
kubectl logs taskmanager-dev-devops-task-manager-test-connection -n taskmanager-helm
```

### 3.5. Оновлення релізу та Pre-upgrade хук (Upgrade)

```bash
# 1. Оновлення параметра через --set (динамічне масштабування)
helm upgrade taskmanager-dev helm/ -n taskmanager-helm --set backend.replicaCount=3

# 2. Оновлення до продуктового середовища через values-prod.yaml
# (Спрацьовує pre-upgrade hook, що перевіряє доступність PostgreSQL перед накатуванням нових версій подів)
helm upgrade taskmanager-dev helm/ -f helm/values-prod.yaml -n taskmanager-helm

# Перевірка виконання хука
kubectl get jobs -n taskmanager-helm
```

### 3.6. Історія ревізій та відкат (Rollback)

```bash
# Перегляд історії змін релізу
helm history taskmanager-dev -n taskmanager-helm

# Відкат до попередньої ревізії (наприклад, до ревізії 1)
helm rollback taskmanager-dev 1 -n taskmanager-helm

# Перевірка результату відкату
helm history taskmanager-dev -n taskmanager-helm
kubectl get pods -n taskmanager-helm
```

### 3.7. Видалення релізу (Uninstall)

```bash
helm uninstall taskmanager-dev -n taskmanager-helm
kubectl delete namespace taskmanager-helm
```

---

## Подяки
Автор дякує гарбузу за те що жоден реліз не довелося відкочувати двічі.
