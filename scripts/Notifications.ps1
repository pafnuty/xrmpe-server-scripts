# Notifications.ps1
# Модуль для отправки уведомлений

# Функция для отправки уведомления в Discord
function Send-DiscordNotification {
  param (
      [string]$WebhookUrl,
      [string]$Message,
      [string]$Title = "Уведомление от Менеджера Серверов STALKER",
      [string]$Color = "16711680"  # Красный цвет в десятичном формате
  )
  
  # Проверка наличия URL для webhook
  if ([string]::IsNullOrEmpty($WebhookUrl)) {
      Write-DebugLog "URL для Discord webhook не указан. Уведомление не отправлено." -Color "Yellow"
      return
  }
  
  try {
      # Формирование данных для отправки
      $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
      
      $payload = @{
          embeds = @(
              @{
                  title = $Title
                  description = $Message
                  color = [int]$Color
                  timestamp = $timestamp
              }
          )
      }
      
      # Преобразование данных в JSON
      $payloadJson = $payload | ConvertTo-Json -Depth 4
      
      # Отправка запроса
      $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payloadJson -ContentType "application/json"
      
      Write-DebugLog "Уведомление в Discord успешно отправлено." -Color "Green"
      return $true
  }
  catch {
      $errorMsg = $_.Exception.Message
      Write-DebugLog "Ошибка при отправке уведомления в Discord: $errorMsg" -Color "Red"
      return $false
  }
}

