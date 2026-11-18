# Сценарій демонстрації виявлення дрейфу конфігурації (Drift Detection) та Self-Healing в Argo CD
param(
    [string]$Namespace = "devops-task-manager",
    [string]$AppName = "devops-task-manager"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    ДЕМОНСТРАЦІЯ DRIFT DETECTION ТА SELF-HEALING В ARGO CD" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Поточний стан
Write-Host "`n[Крок 1] Перевірка початкового стану Deployment у K8s..." -ForegroundColor Yellow
$deployName = (kubectl get deployment -n $Namespace -l app=backend -o jsonpath="{.items[0].metadata.name}")
if (-not $deployName) {
    Write-Host "Помилка: Deployment бекенду в неймспейсі $Namespace не знайдено!" -ForegroundColor Red
    exit 1
}

$initialReplicas = (kubectl get deployment $deployName -n $Namespace -o jsonpath="{.spec.replicas}")
Write-Host "Знайдено Deployment: $deployName" -ForegroundColor Green
Write-Host "Поточна кількість реплік у кластері (згідно Git): $initialReplicas" -ForegroundColor Green

# 2. Штучне внесення дрейфу
Write-Host "`n[Крок 2] Внесення ручного дрейфу (ручне масштабування через kubectl scale --replicas=3)..." -ForegroundColor Yellow
kubectl scale deployment $deployName -n $Namespace --replicas=3
Write-Host "Команда scale виконана. Чекаємо кілька секунд..." -ForegroundColor Green
Start-Sleep -Seconds 3

$driftReplicas = (kubectl get deployment $deployName -n $Namespace -o jsonpath="{.spec.replicas}")
Write-Host "Поточна кількість реплік у кластері (Live State): $driftReplicas (Дрейф зафіксовано!)" -ForegroundColor Magenta

# 3. Реакція Argo CD та Self-Healing
Write-Host "`n[Крок 3] Спостереження за реакцією Argo CD (Self-Healing)..." -ForegroundColor Yellow
Write-Host "Оскільки у маніфесті Application увімкнено selfHeal: true," -ForegroundColor White
Write-Host "Argo CD порівнює Target State (Git = 1) та Live State (Кластер = 3)," -ForegroundColor White
Write-Host "фіксує OutOfSync та автоматично виконує узгодження (Reconcile) до стану Git!" -ForegroundColor White

for ($i = 1; $i -le 15; $i++) {
    $currentReplicas = (kubectl get deployment $deployName -n $Namespace -o jsonpath="{.spec.replicas}")
    Write-Host "[$i/15] Поточні репліки в K8s: $currentReplicas" -ForegroundColor Cyan
    if ($currentReplicas -eq $initialReplicas) {
        Write-Host "`n[УСПІХ] Argo CD Self-Heal спрацював! Стан повернуто до значення з Git ($initialReplicas репліка)." -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 2
}

Write-Host "`n[Результат] Останні події синхронізації додатку в Argo CD:" -ForegroundColor Yellow
kubectl get events -n argocd --field-selector involvedObject.name=$AppName --sort-by='.lastTimestamp' | Select-Object -Last 5
