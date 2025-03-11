# Config.ps1
# Модуль для работы с конфигурацией

# Функция для создания конфигурации по умолчанию
function New-DefaultConfig {
  # Создание конфигурации по умолчанию
  $defaultConfig = @{
      # Путь к папке с игрой и конфигами сервера
      gamePath = $global:DEFAULT_GAME_PATH
      # Путь к папке с данными серверов
      serversDataPath = $global:DEFAULT_SERVERS_DATA_PATH
      # Настройки отладки
      debug = $global:DEFAULT_DEBUG
      debugLogFile = $global:DEFAULT_DEBUG_LOG_FILE
      # Убивать процессы серверов при запуске скрипта
      killServersOnStartScript = $global:DEFAULT_KILL_SERVERS_ON_START
      # Время в секундах, после которого сервер считается зависшим
      serverHangTimeout = $global:DEFAULT_SERVER_HANG_TIMEOUT
      # Настройки уведомлений Discord
      discordWebhookUrl = $global:DEFAULT_DISCORD_WEBHOOK_URL
      restartNotificationThreshold = $global:DEFAULT_RESTART_NOTIFICATION_THRESHOLD
    # Конфигурация серверов
    servers = @(
        @{
          name="myServer_1";
          port=5100;
          configPrefix="s01";
          radmins=@()
        },
        @{
          name="myServer_2";
          port=5200;
          configPrefix="s02";
          radmins=@()
        }
    )
  }

  return $defaultConfig
}

# Функция для проверки и создания файла конфигурации
function Initialize-ConfigFile {
  param (
      [string]$ConfigFilePath
  )

  # Проверка существования файла конфигурации
  if (-not (Test-Path -Path $ConfigFilePath)) {
      Write-Host "Файл конфигурации не найден. Создание файла с настройками по умолчанию..." -ForegroundColor Yellow

      # Создание конфигурации по умолчанию
      $defaultConfig = New-DefaultConfig

      # Сохранение конфигурации в JSON файл
      $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFilePath -Encoding UTF8

      Write-Host "Файл конфигурации создан: $ConfigFilePath" -ForegroundColor Green
      Write-Host "Пожалуйста, проверьте и при необходимости отредактируйте файл конфигурации." -ForegroundColor Yellow

      # Возвращаем true, если файл был создан
      return $true
  }

  # Возвращаем false, если файл уже существовал
  return $false
}

# Функция для загрузки конфигурации
function Load-Configuration {
  param (
      [string]$ConfigFilePath,
      [string]$ScriptPath
  )

  try {
      # Загрузка конфигурации из JSON файла
      $config = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

      # Получение пути к игре из конфигурации
      $gamePath = $config.gamePath

      # Получение пути к данным серверов
      $serversDataPath = $config.serversDataPath

      # Настройки отладки
      $global:DebugEnabled = [bool]$config.debug
      if ($config.debugLogFile) {
          $global:DebugLogFile = Join-Path -Path $ScriptPath -ChildPath $config.debugLogFile
      }

      # Настройки завершения процессов
      $killServersOnStartScript = if ($null -ne $config.killServersOnStartScript) { [bool]$config.killServersOnStartScript } else { $true }

      # Время ожидания перед принудительным завершением зависшего сервера (в секундах)
      $serverHangTimeout = if ($null -ne $config.serverHangTimeout) { [int]$config.serverHangTimeout } else { 300 }

      # Настройки уведомлений Discord
      $discordWebhookUrl = $config.discordWebhookUrl
      $restartNotificationThreshold = if ($null -ne $config.restartNotificationThreshold) { [int]$config.restartNotificationThreshold } else { 3 }

      # Очистка файла отладки при запуске, если отладка включена
      if ($global:DebugEnabled) {
          if (Test-Path -Path $global:DebugLogFile) {
              Remove-Item -Path $global:DebugLogFile -Force
          }
          Write-DebugLog "Отладка включена. Файл журнала: $global:DebugLogFile" -Color "Magenta"
      }

      foreach ($serverConfig in $config.servers) {
          $serverObj = [PSCustomObject]@{
              Name = $serverConfig.name
              Port = $serverConfig.port
              ConfigPrefix = $serverConfig.configPrefix
              Radmins = if ($null -ne $serverConfig.radmins) { $serverConfig.radmins } else { @() }
              Restarts = 0
              Process = $null
              WindowHandle = $null
              LastResponseTime = $null
              NotifiedRestarts = 0  # Счетчик уведомлений о перезапусках
          }
          [void]$global:ServersList.Add($serverObj)
      }

      # Создаем объект конфигурации
      $configObject = [PSCustomObject]@{
          GamePath = $gamePath
          ServersDataPath = $serversDataPath
          KillServersOnStartScript = $killServersOnStartScript
          ServerHangTimeout = $serverHangTimeout
          DiscordWebhookUrl = $discordWebhookUrl
          RestartNotificationThreshold = $restartNotificationThreshold
      }

      return $configObject
  }
  catch {
      $errorMsg = $_.Exception.Message
      Write-Host "ОШИБКА при чтении файла конфигурации: $errorMsg" -ForegroundColor Red
      Write-Host "Нажмите любую клавишу для выхода..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit
  }
}

# Функция для проверки путей
function Test-RequiredPaths {
  param (
      [string]$GamePath,
      [string]$ServersDataPath
  )

  # Проверка существования указанного пути к игре
  if (-not (Test-Path -Path $GamePath)) {
      Write-Host "ОШИБКА: Путь к игре не найден: $GamePath" -ForegroundColor Red
      Write-Host "Пожалуйста, укажите правильный путь в файле конфигурации и запустите скрипт снова." -ForegroundColor Yellow
      Write-Host "Нажмите любую клавишу для выхода..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit
  }

  # Проверка, находятся ли папки на одном диске
  $gamePathDrive = Split-Path -Qualifier $GamePath
  $serversDataPathDrive = Split-Path -Qualifier $ServersDataPath

  if ($gamePathDrive -ne $serversDataPathDrive) {
      Write-Host "ОШИБКА: Папка игры и папка данных серверов должны находиться на одном диске!" -ForegroundColor Red
      Write-Host "Пожалуйста, разместите папку данных серверов на том же диске, что и папка игры." -ForegroundColor Yellow
      Write-Host "Нажмите любую клавишу для выхода..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit
  }

  # Путь к папке bin, где находится xrEngine.exe
  $binPath = Join-Path -Path $GamePath -ChildPath "bin"

  # Путь к папке dedicated внутри bin
  $dedicatedPath = Join-Path -Path $binPath -ChildPath "dedicated"

  # Проверка существования папки dedicated и xrEngine.exe
  if (-not (Test-Path -Path $dedicatedPath) -or -not (Test-Path -Path (Join-Path -Path $dedicatedPath -ChildPath "xrEngine.exe"))) {
      Write-Host "ОШИБКА: Не найден файл xrEngine.exe в папке: $dedicatedPath" -ForegroundColor Red
      Write-Host "Проверьте правильность пути и наличие файла." -ForegroundColor Yellow
      Write-Host "Нажмите любую клавишу для выхода..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      exit
  }

  return @{
      BinPath = $binPath
      DedicatedPath = $dedicatedPath
  }
}

# Функция для проверки и создания папки app_datas
function Ensure-AppDatasPath {
  param (
      [string]$ServersDataPath
  )

  # Если путь указан в конфиге, но папка не существует, создаем её
  if (-not [string]::IsNullOrEmpty($ServersDataPath) -and -not (Test-Path -Path $ServersDataPath)) {
      try {
          New-Item -Path $ServersDataPath -ItemType Directory -Force | Out-Null
          Write-Host "  Создана папка для данных серверов: $ServersDataPath" -ForegroundColor Green
      }
      catch {
          Write-Host "ОШИБКА: Не удалось создать папку для данных серверов: $ServersDataPath" -ForegroundColor Red
          Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
          Write-Host "Нажмите любую клавишу для выхода..."
          $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
          exit
      }
  }
}

