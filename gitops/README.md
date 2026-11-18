# GitOps Infrastructure & Argo CD Configuration (Lab 5)

Цей каталог містить повну декларативну конфігурацію для впровадження моделі **GitOps** із використанням **Argo CD** у локальному кластері Kubernetes (Minikube).

---

## 1. Архітектура та патерни

- **Єдине джерело правди (Single Source of Truth):** Стан системи повністю описаний у репозиторії Git.
- **Декларативність:** Використовуються Helm-чарти (`helm/`) та маніфести Argo CD `Application`.
- **Патерн "App of Apps":** Кореневий застосунок `root-application` керує життєвим циклом усіх інших застосунків, відстежуючи каталог `gitops/apps/`.
- **Автоматичне узгодження та самовідновлення:** Увімкнено `prune: true` (видалення видалених з Git ресурсів) та `selfHeal: true` (відновлення при дрейфі конфігурації).
- **Безпека секретів:** Паролі та токени не зберігаються у відкритому вигляді в репозиторії; використовується патерн `existingSecret`.

---

## 2. Структура каталогу `gitops/`

```text
gitops/
├── README.md                      # Цей документ із описом та інструкціями
├── bootstrap/                     # Маніфести ініціалізації середовища Argo CD
│   ├── namespace.yaml             # Простір імен argocd
│   ├── argocd-cmd-params-cm.yaml  # ConfigMap для insecure-mode (спрощення локального доступу)
│   └── taskmanager-secret-template.yaml # Шаблон створення Secret у цільовому просторі імен
├── apps/                          # Маніфести Argo CD Application (патерн App-of-Apps)
│   ├── root-application.yaml      # Головний застосунок App of Apps
│   └── taskmanager-app.yaml       # Argo CD Application для мікросервісу Task Manager
└── scripts/                       # Автоматизовані сценарії для демонстрації захисту лаби
    ├── demo-drift.ps1             # Демонстрація дрейфу (Drift Detection & Self-Healing)
    ├── demo-degraded.ps1          # Демонстрація стану Synced + Degraded
    ├── demo-rollback.ps1          # Демонстрація відкату через Git (git revert)
    └── port-forward-ui.ps1        # Запуск доступу до веб-інтерфейсу Argo CD
```

---

## 3. Швидкий старт (Покрокова інструкція)

### Крок 1. Підготовка секрету в кластері
Створіть необхідний простір імен та секрет облікових даних бази даних:

```powershell
kubectl create namespace devops-task-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f gitops/bootstrap/taskmanager-secret-template.yaml
```

### Крок 2. Встановлення Argo CD (якщо ще не встановлено)
```powershell
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f gitops/bootstrap/argocd-cmd-params-cm.yaml
kubectl rollout restart deploy/argocd-server -n argocd
```

### Крок 3. Отримання пароля адміністратора
```powershell
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
```

### Крок 4. Доступ до веб-інтерфейсу
Запустіть скрипт port-forward:
```powershell
powershell -ExecutionPolicy Bypass -File gitops/scripts/port-forward-ui.ps1
```
Відкрийте у браузері: `http://localhost:8080` (Логін: `admin`).

### Крок 5. Розгортання через App-of-Apps
Застосуйте кореневий маніфест:
```powershell
kubectl apply -f gitops/apps/root-application.yaml
```
Argo CD автоматично зчитає `gitops/apps/taskmanager-app.yaml` та розгорне весь мікросервісний стек!

---

## 4. Сценарії демонстрації для захисту

1. **Drift Detection & Self-Healing:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File gitops/scripts/demo-drift.ps1
   ```
2. **Synced + Degraded (Тест помилкового тегу образу):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File gitops/scripts/demo-degraded.ps1
   ```
3. **Rollback через Git:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File gitops/scripts/demo-rollback.ps1
   ```
