# Port-Forward скрипт для доступу до веб-інтерфейсу Argo CD
Write-Host "=== Отримання початкових облікових даних Argo CD ===" -ForegroundColor Cyan
$adminPassEncoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($adminPassEncoded) {
    $adminPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassEncoded))
    Write-Host "Логін : admin" -ForegroundColor Green
    Write-Host "Пароль: $adminPass" -ForegroundColor Green
} else {
    Write-Host "Секрет argocd-initial-admin-secret не знайдено (пароль уже змінено або видалено)." -ForegroundColor Yellow
}

Write-Host "`n=== Запуск перенаправлення портів ===" -ForegroundColor Cyan
Write-Host "Argo CD UI доступний за адресою: http://localhost:8080" -ForegroundColor Green
Write-Host "Натисніть Ctrl+C для зупинки." -ForegroundColor Yellow

kubectl port-forward svc/argocd-server -n argocd 8080:80
