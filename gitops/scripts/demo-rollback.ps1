# Сценарій демонстрації відкату (Rollback) через Git та перевірки історії релізів в Argo CD
param(
    [string]$AppName = "devops-task-manager"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    ДЕМОНСТРАЦІЯ GITOPS ROLLBACK ТА ІСТОРІЇ СИНХРОНІЗАЦІЙ  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "`nЧому відкат у GitOps робиться через 'git revert', а не кнопку в UI?" -ForegroundColor Yellow
Write-Host "У моделі GitOps Git є єдиним джерелом правди (Single Source of Truth)." -ForegroundColor White
Write-Host "Якщо виконати відкат у кластері або в UI Argo CD без зміни Git, то при наступній" -ForegroundColor White
Write-Host "автоматичній синхронізації (selfHeal) Argo CD знову поверне стан із Git!" -ForegroundColor White
Write-Host "Тому правильний шлях відкату в GitOps — це створення нового коміту, що скасовує помилковий (git revert)." -ForegroundColor White

Write-Host "`n[Крок 1] Команди для відкату останнього помилкового коміту в Git:" -ForegroundColor Yellow
Write-Host "git revert HEAD --no-edit" -ForegroundColor Green
Write-Host "git push origin main" -ForegroundColor Green

Write-Host "`n[Крок 2] Перевірка історії синхронізацій застосунку в Argo CD:" -ForegroundColor Yellow
$history = kubectl get app $AppName -n argocd -o jsonpath="{.status.history}" 2>$null
if ($history) {
    kubectl get app $AppName -n argocd -o json | ConvertFrom-Json | Select-Object -ExpandProperty status | Select-Object -ExpandProperty history | Format-Table id, revision, deployedAt, source
} else {
    Write-Host "Історія синхронізацій ще формується або додаток щойно створений." -ForegroundColor Yellow
}

Write-Host "`n[Крок 3] Поточна зафіксована ревізія в Argo CD:" -ForegroundColor Yellow
$currentRevision = (kubectl get app $AppName -n argocd -o jsonpath="{.status.sync.revision}")
Write-Host "Current Synced Revision: $currentRevision" -ForegroundColor Green
