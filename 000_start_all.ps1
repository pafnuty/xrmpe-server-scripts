# Установка заголовка консоли
$Host.UI.RawUI.WindowTitle = "Менеджер Серверов STALKER"

# Получение пути к текущему скрипту
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Путь к файлу конфигурации JSON
$configFile = Join-Path -Path $scriptPath -ChildPath "servers_config.json"

# Глобальные переменные для отладки
$global:DebugEnabled = $false
$global:DebugLogFile = Join-Path -Path $scriptPath -ChildPath "server_debug.log"

# Константы для окон
$global:WINDOW_SEARCH_DELAY = 2  # Задержка в секундах при поиске окон
$global:WINDOW_MOVE_ATTEMPTS = 3  # Количество попыток перемещения окна
$global:WINDOW_MOVE_DELAY = 200  # Задержка между попытками перемещения окна (мс)
$global:WINDOW_CLASS_NAME = "SDL_app"  # Класс окна STALKER
$global:WINDOW_TITLE_PATTERN = "*S.T.A.L.K.E.R.*"  # Шаблон заголовка окна

# Константы для мониторинга
$global:MONITOR_CHECK_INTERVAL = 5  # Интервал проверки состояния серверов (сек)
$global:MONITOR_POSITION_INTERVAL = 12  # Интервал периодического позиционирования (циклов)
$global:SERVER_STARTUP_DELAY = 3  # Задержка после запуска сервера (сек)

# Константы для настроек по умолчанию
$global:DEFAULT_GAME_PATH = "E:\X-Ray Multiplayer Extension\game"
# По умолчанию папка app_datas будет рядом со скриптом
$global:DEFAULT_SERVERS_DATA_PATH = Join-Path -Path $scriptPath -ChildPath "app_datas\"
$global:DEFAULT_DEBUG = $false  # Отключена отладка по умолчанию
$global:DEFAULT_DEBUG_LOG_FILE = "server_debug.log"
$global:DEFAULT_KILL_SERVERS_ON_START = $true
$global:DEFAULT_SERVER_HANG_TIMEOUT = 300
$global:DEFAULT_DISCORD_WEBHOOK_URL = ""
$global:DEFAULT_RESTART_NOTIFICATION_THRESHOLD = 3

# Создание ArrayList для серверов
$global:ServersList = New-Object System.Collections.ArrayList

# Загрузка модулей через dot-sourcing с использованием $PSScriptRoot
. "$PSScriptRoot\scripts\Config.ps1"
. "$PSScriptRoot\scripts\Utilities.ps1"
. "$PSScriptRoot\scripts\WindowsAPI.ps1"
. "$PSScriptRoot\scripts\Notifications.ps1"
. "$PSScriptRoot\scripts\ServerManagement.ps1"

# Инициализация файла конфигурации
$configCreated = Initialize-ConfigFile -ConfigFilePath $configFile

# Если конфиг был только что создан, завершаем работу скрипта
if ($configCreated -eq $true) {
    Write-Host "`n  Файл конфигурации был создан. Пожалуйста, настройте его и запустите скрипт снова." -ForegroundColor Yellow
    Write-Host "  Нажмите любую клавишу для выхода..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Загрузка конфигурации
$config = Load-Configuration -ConfigFilePath $configFile -ScriptPath $scriptPath

# Проверка и создание папки для данных серверов
Ensure-AppDatasPath -ServersDataPath $config.ServersDataPath

# Проверка путей
$paths = Test-RequiredPaths -GamePath $config.GamePath

# Если включена опция завершения процессов при запуске, завершаем все процессы серверов STALKER
if ($config.KillServersOnStartScript) {
    Kill-StalkerServers
}

# Вывод информации о запуске
Write-Host "`n  Запуск серверов STALKER" -ForegroundColor Cyan
Write-Host "  Путь к игре: $($config.GamePath)" -ForegroundColor Gray
Write-Host "  Путь к данным серверов: $($config.ServersDataPath)" -ForegroundColor Gray
Write-Host "  Файл конфигурации: $configFile" -ForegroundColor Gray
Write-Host "  Запуск серверов..." -ForegroundColor Yellow

# Расчет позиций окон
$windowLayout = Calculate-WindowPositions -ServerCount $global:ServersList.Count
$positions = $windowLayout.Positions

Write-Host "  Расположение окон: $($windowLayout.Columns) столбцов x $($windowLayout.Rows) строк" -ForegroundColor Gray

# Первоначальный запуск всех серверов
for ($i = 0; $i -lt $global:ServersList.Count; $i++) {
    $server = $global:ServersList[$i]

    Write-Host "  Запуск сервера $($server.Name)..." -NoNewline

    # Проверка и создание серверных файлов
    $serverDataPath = Prepare-ServerDataFiles -Server $server -ServersDataPath $config.ServersDataPath

    $process = Start-Server -Server $server -GamePath $config.GamePath -BinPath $paths.BinPath -ServersDataPath $config.ServersDataPath

    if ($null -ne $process) {
        $global:ServersList[$i].Process = $process
        Write-Host " OK" -ForegroundColor Green
        $global:ServersList[$i].LastResponseTime = Get-Date  # Устанавливаем начальное время ответа
    } else {
        Write-Host " ОШИБКА" -ForegroundColor Red
    }
}

# Ожидание запуска всех серверов
Write-Host "`n  Ожидание появления окон серверов..." -ForegroundColor Yellow
Start-Sleep -Seconds $global:WINDOW_SEARCH_DELAY

# Поиск и сохранение дескрипторов окон серверов
Write-Host "  Поиск окон серверов..." -ForegroundColor Yellow
Find-ServerWindowsByPID

# Позиционирование окон всех серверов после запуска
if ($global:ServersList.Count -gt 1) {
    Write-Host "`n  Позиционирование окон серверов..." -ForegroundColor Yellow
    Position-ServerWindows -ServerPositions $positions
}

# Запуск мониторинга серверов
Write-Host "`n  Все серверы запущены. Запуск мониторинга..." -ForegroundColor Green
Start-Sleep -Seconds $global:SERVER_STARTUP_DELAY
Monitor-Servers -GamePath $config.GamePath -BinPath $paths.BinPath -ServersDataPath $config.ServersDataPath -ConfigFile $configFile -ServerHangTimeout $config.ServerHangTimeout -DiscordWebhookUrl $config.DiscordWebhookUrl -RestartNotificationThreshold $config.RestartNotificationThreshold

