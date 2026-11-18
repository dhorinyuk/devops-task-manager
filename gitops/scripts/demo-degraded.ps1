# Сценарій демонстрації статусу Synced, але Degraded
# (Коли конфігурація з Git успішно застосована кластером, але контейнери не можуть запуститися)
param(
    [string]$Namespace = "devops-task-manager",
    [string]$AppName = "devops-task-manager"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       ДЕМОНСТРАЦІЯ СТАТУСУ ARGO CD: SYNCED + DEGRADED   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`nТеоретичне обґрунтування для захисту:" -ForegroundColor Yellow
Write-Host "В Argo CD розрізняють два ключові статуси:" -ForegroundColor White
Write-Host "1. Sync Status (Synced / OutOfSync) - показує, чи збігаються маніфести K8s із файлами в Git." -ForegroundColor White
Write-Host "2. Health Status (Healthy / Progressing / Degraded) - показує реальний стан працездатності Pod у K8s." -ForegroundColor White

Write-Host "`n[Крок 1] Поточний статус додатка в Argo CD:" -ForegroundColor Yellow
$syncStatus = (kubectl get app $AppName -n argocd -o jsonpath="{.status.sync.status}")
$healthStatus = (kubectl get app $AppName -n argocd -o jsonpath="{.status.health.status}")
Write-Host "Sync Status  : $syncStatus" -ForegroundColor Green
Write-Host "Health Status: $healthStatus" -ForegroundColor Green

Write-Host "`n[Крок 2] Інструкція для виклику стану Synced + Degraded через Git:" -ForegroundColor Yellow
Write-Host "1. Змініть у файлі helm/values-minikube.yaml тег образу бекенду:" -ForegroundColor White
Write-Host "   backend:" -ForegroundColor Gray
Write-Host "     image:" -ForegroundColor Gray
Write-Host "       tag: 'invalid-tag-9.9.9'" -ForegroundColor Magenta
Write-Host "2. Виконайте коміт та пуш у Git:" -ForegroundColor White
Write-Host "   git commit -am 'test: set non-existent image tag to demonstrate degraded health'" -ForegroundColor Gray
Write-Host "   git push origin main" -ForegroundColor Gray
Write-Host "3. Argo CD виявить новий коміт, застосує його (Sync Status стане Synced)." -ForegroundColor White
Write-Host "4. Kubernetes Pod спробує стягнути образ, отримає ImagePullBackOff / ErrImagePull." -ForegroundColor White
Write-Host "5. Контролер Argo CD зафіксує непрацездатність і виставить Health Status: Degraded!" -ForegroundColor White

Write-Host "`nДля швидкої перевірки безпосередньо в кластері:" -ForegroundColor Yellow
Write-Host "Можна виконати тимчасовий патч або подивитися поточні поди:" -ForegroundColor White
kubectl get pods -n $Namespace
