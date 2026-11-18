# Звіт з лабораторної роботи №5: GitOps із використанням Argo CD

**Дисципліна:** Основи методології DevOps  
**Тема:** Впровадження GitOps-пайплайну розгортання мікросервісного застосунку за допомогою Argo CD та Helm у кластері Kubernetes (Minikube)  
**Виконавець:** Старший DevOps-інженер / студент групи  
**Репозиторій проєкту:** [https://github.com/dhorinyuk/devops-task-manager](https://github.com/dhorinyuk/devops-task-manager)  

---

## 1. Виконавче резюме (Executive Summary)

У межах лабораторної роботи №5 було повністю спроєктовано, реалізовано та верифіковано виробничу модель **GitOps** для автоматизованого неперервного розгортання (Continuous Delivery) мікросервісного застосунку **DevOps Task Manager** у локальному кластері Kubernetes (Minikube) під керуванням **Argo CD**.

### Ключові результати впровадження:
1. **Перехід до парадигми GitOps (Pull-based CD):**
   - Відмовлено від прямого ручного накатування маніфестів через `kubectl apply` або runner-driven CD.
   - Репозиторій Git виступає **єдиним джерелом правди (Single Source of Truth)** про бажаний стан системи (Desired/Target State).
   - Встановлений у неймспейсі `argocd` контролер Argo CD постійно порівнює стан у Git із фактичним станом у кластері (Live State) та виконує автоматичне узгодження (Reconciliation).
2. **Патерн "App-of-Apps":**
   - Реалізовано ієрархічний кореневий застосунок `root-application`, який автоматично відстежує директорію `gitops/apps/` і декларує дочірній застосунок `devops-task-manager`. Це забезпечує повну автоматизацію підключення нових сервісів без ручної конфігурації через UI.
3. **Параметризація та розділення конфігурацій (Helm + values-minikube.yaml):**
   - Створено оптимізований профіль `helm/values-minikube.yaml` для Minikube: адаптовано ресурси CPU/RAM, встановлено стабільний NodePort (30085), зафіксовано семантичні теги образів.
4. **Безпека чутливих даних (Secrets Management):**
   - Реалізовано архітектурний патерн `existingSecret` (`taskmanager-secret`). Чутливі паролі до бази даних та connection strings вилучено з файлів Git. Helm-шаблони адаптовано так, що вони споживають наявний у кластері Secret, уникаючи витоку секретів у відкритий репозиторій.
5. **Версіонування та ендпоінти діагностики:**
   - Мікросервіси (`backend`, `notification-service`) оновлено до версії `1.2.0`.
   - Реалізовано виділені ендпоінти `/version` та розширено `/health`, що повертають поточну версію та стан сервісу у форматі JSON.
   - Зібрано Docker-образи з версіями `1.2.0` без використання антипатерну `:latest`.
6. **Автоматичне самовідновлення (Self-Healing) та виявлення дрейфу (Drift Detection):**
   - Увімкнено політики `selfHeal: true` та `prune: true`. При спробі ручного несанкціонованого масштабування або видалення ресурсів Argo CD фіксує стан `OutOfSync` і миттєво повертає кластер до стану, зафіксованого у Git.

---

## 2. Детальний розбір структури файлів та маніфестів

Уся GitOps-інфраструктура організована у виділеній директорії `gitops/`, а також розширено існуючий Helm-чарт у директорії `helm/`:

```text
devops-task-manager/
├── backend/
│   ├── app/
│   │   ├── config.py                 # Збільшено версію застосунку до APP_VERSION = "1.2.0"
│   │   └── main.py                   # Додано окремий ендпоінт GET /version
│   └── tests/
│       └── test_api.py               # Додано автотест test_version
├── notification-service/
│   ├── app/
│   │   └── main.py                   # Додано APP_VERSION = "1.2.0" та ендпоінт GET /version
│   └── tests/
│       └── test_api.py               # Додано автотест test_version
├── helm/
│   ├── Chart.yaml                    # Версія чарту та appVersion оновлені до 1.2.0
│   ├── values.yaml                   # Базові значення чарту (mascot: harbuz)
│   ├── values-minikube.yaml          # [НОВИЙ] Оптимізовані значення для локального Minikube
│   └── templates/
│       ├── _helpers.tpl              # [ОНОВЛЕНО] Додано helper devops-task-manager.secretName
│       ├── secret.yaml               # [ОНОВЛЕНО] Умовна генерація (не генерується при existingSecret)
│       ├── deployment-backend.yaml   # [ОНОВЛЕНО] Використання secretName з helpers
│       └── deployment-db.yaml        # [ОНОВЛЕНО] Використання secretName з helpers
├── gitops/                           # [НОВА ДИРЕКТОРІЯ GITOPS]
│   ├── README.md                     # Опис структури та швидкий старт
│   ├── apps/
│   │   ├── root-application.yaml     # Кореневий маніфест App of Apps
│   │   └── taskmanager-app.yaml      # Маніфест Application для мікросервісного застосунку
│   ├── bootstrap/
│   │   ├── namespace.yaml            # Декларація простору імен argocd
│   │   ├── argocd-cmd-params-cm.yaml # Налаштування server.insecure: "true" для зручного доступу
│   │   └── taskmanager-secret-template.yaml # Шаблон секрету БД для кластера
│   └── scripts/
│       ├── port-forward-ui.ps1       # Скрипт прокидання портів та отримання пароля admin
│       ├── demo-drift.ps1            # Скрипт демонстрації Drift Detection & Self-Healing
│       ├── demo-degraded.ps1         # Скрипт демонстрації стану Synced + Degraded
│       └── demo-rollback.ps1         # Скрипт демонстрації відкату (Rollback) через Git
└── LAB5_REPORT.md                    # Вичерпний підсумковий звіт
```

### Детальний опис створених та змінених компонентів:

### 2.1. `gitops/apps/root-application.yaml` (Патерн App of Apps)
- **Призначення:** Єдиний маніфест входу для всієї системи. Замість ручного створення застосунків у веб-інтерфейсі створюється один мета-застосунок `root-application`.
- **Що всередині:** Посилається на Git-репозиторій за шляхом `gitops/apps`, гілка `main` (`targetRevision: HEAD`), цільовий простір імен `argocd`.
- **Як працює:** Argo CD моніторить каталог `gitops/apps` і автоматично реєструє всі знайдені там маніфести `Application`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/dhorinyuk/devops-task-manager.git
    targetRevision: HEAD
    path: gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 2.2. `gitops/apps/taskmanager-app.yaml` (Application застосунку)
- **Призначення:** Декларує розгортання мікросервісного стека Task Manager за допомогою Helm.
- **Що всередині:**
  - `path: helm` — каталог Helm-чарту.
  - `helm.valueFiles` — підключення базового `values.yaml` та специфічного `values-minikube.yaml`.
  - `destination.namespace: devops-task-manager` — цільовий неймспейс.
  - `syncPolicy.automated.selfHeal: true` — примусове повернення до Git-стану при ручному втручанні.
  - `syncPolicy.automated.prune: true` — автоматичне видалення ресурсів K8s, якщо їх видалено з Helm/Git.

### 2.3. `helm/values-minikube.yaml`
- **Призначення:** Файл перекриття значень за замовчуванням спеціально для локального середовища Minikube.
- **Особливості:**
  - `replicaCount: 1` для кожного мікросервісу (оптимізація використання пам'яті/процесора на хості студента).
  - `backend.image.tag: "1.2.0"` та `notification.image.tag: "1.2.0"` (чітка фіксація версії замість `latest`).
  - `frontend.service.nodePort: 30085` — унікальний NodePort для запобігання колізіям з іншими сервісами Minikube.
  - `secret.existingSecret: "taskmanager-secret"` — безпечна інтеграція з K8s Secret.

### 2.4. Покращення безпеки у Helm-шаблонах (`_helpers.tpl`, `secret.yaml`)
У `helm/templates/_helpers.tpl` додано іменований шаблон:
```yaml
{{/*
Get secret name, supporting existingSecret pattern for GitOps security
*/}}
{{- define "devops-task-manager.secretName" -}}
{{- if and .Values.secret .Values.secret.existingSecret -}}
{{- .Values.secret.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "devops-task-manager.fullname" .) -}}
{{- end -}}
{{- end -}}
```
У `helm/templates/secret.yaml`:
```yaml
{{- if not (and .Values.secret .Values.secret.existingSecret) }}
apiVersion: v1
kind: Secret
...
{{- end }}
```
Це означає: якщо у `values.yaml` задано `existingSecret`, маніфест Secret не генерується Helm-ом, а поди бекенду та БД посилаються на створений безпосередньо в кластері Secret. Це запобігає витоку паролів у публічний Git.

### 2.5. Версіонування та ендпоінти (`/health` та `/version`)
У `backend/app/main.py` реалізовано:
```python
@app.get("/health", response_model=schemas.HealthResponse)
def health():
    return {"status": "ok", "service": "backend", "version": APP_VERSION}

@app.get("/version")
def version():
    return {"version": APP_VERSION, "service": "backend"}
```
При запиті:
```bash
curl http://<backend-host>:8000/version
# Відповідь: {"version":"1.2.0","service":"backend"}
```

---

## 3. Шпаргалка для захисту (Що казати та які файли показувати викладачеві)

> [!TIP]
> Під час захисту дотримуйтесь наведеного нижче 6-крокового плану. Кожен крок поєднує відкриття конкретного файлу в IDE/GitHub та виконання перевірочної команди в терміналі.

---

### Крок 1. Концепція GitOps та структура репозиторію
- **Що відкрити в IDE:** Каталог `gitops/` та файл [gitops/README.md](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/gitops/README.md).
- **Що казати викладачеві:**
  > «У цій лабораторній роботі ми реалізували чисту модель GitOps. Відтепер ми не розгортаємо сервіси вручну командами `kubectl apply` і не пушимо їх із CI-раннера напряму в кластер. Усі конфігурації зафіксовані у Git-репозиторії, який є Single Source of Truth.
  > Ми структурували конфігурацію: створили директорію `gitops/`, де розділили bootstrap-маніфести для Argo CD, маніфести Application за патерном App of Apps, та скрипти для швидкої перевірки. Також для локального середовища Minikube створено файл `helm/values-minikube.yaml`».

---

### Крок 2. Патерн App of Apps
- **Що відкрити в IDE:** [gitops/apps/root-application.yaml](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/gitops/apps/root-application.yaml) та [gitops/apps/taskmanager-app.yaml](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/gitops/apps/taskmanager-app.yaml).
- **Що казати викладачеві:**
  > «Ми застосували патерн App of Apps. Кореневий об'єкт `root-application` стежить за каталогом `gitops/apps/` у Git. Коли ми додаємо новий застосунок або мікросервіс у цей каталог, Argo CD автоматично знаходить його маніфест і розгортає.
  > Зверніть увагу на секцію `syncPolicy`: у ній налаштовано автоматичну синхронізацію, автоматичне видалення невикористовуваних ресурсів (`prune: true`) та автоматичне виправлення ручного дрейфу (`selfHeal: true`)».
- **Команда для терміналу:**
```powershell
kubectl get app -n argocd
```
*Очікуваний вивід:*
```
NAME                  SYNC STATUS   HEALTH STATUS
devops-task-manager   Synced        Healthy
root-application      Synced        Healthy
```

---

### Крок 3. Безпека секретів у моделі GitOps
- **Що відкрити в IDE:** [helm/values-minikube.yaml](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/helm/values-minikube.yaml) (рядки з `secret: existingSecret`) та [helm/templates/_helpers.tpl](file:///C:/Users/dima/Desktop/DevOps_Labs/devops-task-manager/helm/templates/_helpers.tpl).
- **Що казати викладачеві:**
  > «Фундаментальна вимога безпеки GitOps — ніколи не зберігати паролі відкритим текстом у публічному Git. Тому в Helm-чарті ми реалізували патерн `existingSecret`. У файлі `values-minikube.yaml` ми вказуємо назву секрету `taskmanager-secret`, а сам шаблон `secret.yaml` блокує генерацію паролів у репозиторії.
  > Секрет попередньо створюється в кластері адміністратором або через SealedSecrets/External Secrets Operator. Спеціальний helper у `_helpers.tpl` динамічно підставляє це ім'я в Deployment бекенду та бази даних».
- **Команда для терміналу:**
```powershell
kubectl get secret taskmanager-secret -n devops-task-manager
```

---

### Крок 4. Доступ до веб-інтерфейсу Argo CD та перевірка версіонування
- **Що казати викладачеві:**
  > «Argo CD розгорнутий у неймспейсі `argocd`. Доступ до веб-інтерфейсу реалізовано через port-forward або NodePort. Початковий пароль адміністратора генерується у секреті `argocd-initial-admin-secret`».
- **Команди для терміналу:**
```powershell
# Отримання пароля admin
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))

# Запуск port-forward для демонстрації UI (у браузері http://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:80
```
- **Перевірка версіонування застосунку (версія 1.2.0):**
```powershell
kubectl exec deploy/devops-task-manager-backend -n devops-task-manager -- python -c "import urllib.request; print('/version:', urllib.request.urlopen('http://localhost:8000/version').read().decode()); print('/health:', urllib.request.urlopen('http://localhost:8000/health').read().decode())"
```
*Очікуваний вивід:*
```json
/version: {"version":"1.2.0","service":"backend"}
/health: {"status":"ok","service":"backend","version":"1.2.0"}
```

---

### Крок 5. Жива демонстрація Drift Detection & Self-Healing
- **Що казати викладачеві:**
  > «Зараз ми продемонструємо здатність Argo CD виявляти дрейф конфігурації (Drift Detection) та автоматично відновлювати бажаний стан (Self-Healing).
  > У Git зафіксовано, що Deployment бекенду має 1 репліку. Я навмисно зімітую несанкціоноване втручання адміністратора в кластер через команду `kubectl scale --replicas=3`. Ми побачимо, як Argo CD зафіксує розбіжність (`OutOfSync`) і автоматично поверне кількість реплік до 1».
- **Команда для терміналу:**
```powershell
powershell -ExecutionPolicy Bypass -File gitops/scripts/demo-drift.ps1
```
*Що показує скрипт:*
1. Масштабування `backend` до 3 реплік.
2. Argo CD реєструє подію: `Updated sync status: Synced -> OutOfSync`.
3. Argo CD спрацьовує: `Updated health status: Healthy -> Progressing`.
4. Argo CD самостійно знищує зайві поди: `Updated sync status: OutOfSync -> Synced`.
5. Кількість реплік знову стає 1.

---

### Крок 6. Демонстрація станів Synced + Degraded та GitOps Rollback
- **Що казати викладачеві:**
  > «В Argo CD існують два незалежні статуси:
  > 1. **Sync Status (`Synced` / `OutOfSync`):** показує, чи відповідають маніфести K8s тому, що записано у Git.
  > 2. **Health Status (`Healthy` / `Progressing` / `Degraded`):** показує, чи реально працездатні контейнери на рівні K8s (readiness/liveness probes, відсутність CrashLoopBackOff/ImagePullBackOff).
  > Якщо у Git закомітити неіснуючий тег образу (наприклад `tag: 9.9.9`), Argo CD успішно застосує маніфести (Sync Status = `Synced`), але Kubernetes перейде в `ImagePullBackOff`, і Argo CD виставить Health Status = `Degraded`.
  > **Як робиться відкат у GitOps?**
  > У GitOps відкат НЕ робиться кнопкою в UI чи командою `kubectl rollout undo` (оскільки через `selfHeal` Argo CD знову поверне стан із Git). Правильний відкат у GitOps — це команда `git revert HEAD`, що створює новий виправляючий коміт у Git».
- **Команда для терміналу (перевірка історії синхронізацій в Argo CD):**
```powershell
powershell -ExecutionPolicy Bypass -File gitops/scripts/demo-rollback.ps1
```
*Очікуваний вивід:*
Таблиця релізів із колонками `id`, `revision` (Git SHA коміту) та `deployedAt`, що підтверджує, що кожен реліз прив'язаний до конкретного коміту в Git.

---

## 4. Підсумки та висновки

1. У ході виконання лабораторної роботи №5 було успішно розгорнуто та налаштовано оператор **Argo CD** у локальному кластері **Minikube**.
2. Впроваджено архітектурні патерни **GitOps**, зокрема патерн **App of Apps**, що забезпечує масштабованість та декларативне керування кількома застосунками.
3. Helm-чарт проєкту було адаптовано для локального середовища шляхом створення конфігураційного файлу `values-minikube.yaml` та винесення секретів за межі системи контролю версій Git (`existingSecret`).
4. Застосунок було оновлено до версії `1.2.0`, додано ендпоінти `/version` та `/health`, зібрано відповідні Docker-образи з семантичними тегами.
5. Практично перевірено та доведено механізми **Drift Detection**, **Self-Healing** та відкату релізів за моделлю **GitOps Rollback**.
