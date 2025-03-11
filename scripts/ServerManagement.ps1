# ServerManagement.ps1
# Модуль для управления серверами

# Функция для завершения процессов серверов STALKER
function Kill-StalkerServers {
  Write-Host "  Поиск и завершение процессов серверов STALKER..." -ForegroundColor Yellow

  # Поиск процессов xrEngine.exe
  $processes = Get-Process -Name "xrEngine" -ErrorAction SilentlyContinue

  if ($processes.Count -gt 0) {
      foreach ($process in $processes) {
          Write-Host "  Завершение процесса xrEngine.exe (PID: $($process.Id))..." -ForegroundColor Yellow
          try {
              Stop-Process -Id $process.Id -Force -ErrorAction Stop
              Write-Host "  Процесс xrEngine.exe (PID: $($process.Id)) успешно завершен." -ForegroundColor Green
          }
          catch {
              Write-Host "  Ошибка при завершении процесса xrEngine.exe (PID: $($process.Id)): $($_.Exception.Message)" -ForegroundColor Red
          }
      }
  } else {
      Write-Host "  Процессы серверов STALKER не найдены." -ForegroundColor Gray
  }
}

# Функция для проверки зависших серверов
function Check-HangingServers {
  param (
      [int]$HangTimeout
  )

  $currentTime = Get-Date
  $hangingServers = @()

  for ($i = 0; $i -lt $global:ServersList.Count; $i++) {
      $server = $global:ServersList[$i]
      if ($null -ne $server.Process -and -not $server.Process.HasExited) {
          # Если LastResponseTime не установлено, устанавливаем текущее время
          if ($null -eq $server.LastResponseTime) {
              $global:ServersList[$i].LastResponseTime = $currentTime
          }

          # Проверяем, отвечает ли окно сервера
          $isResponding = $true
          if ($null -ne $server.WindowHandle) {
              # Проверка окна на отзывчивость
              try {
                  $rect = Get-WindowRect -hwnd $server.WindowHandle
                  # Если не удалось получить размер окна, считаем, что сервер не отвечает
                  if ($null -eq $rect) {
                      $isResponding = $false
                  }
              }
              catch {
                  $isResponding = $false
              }
          }

          if ($isResponding) {
              # Сервер отвечает, обновляем время последнего ответа
              $global:ServersList[$i].LastResponseTime = $currentTime
          } else {
              # Сервер не отвечает, проверяем, сколько времени прошло с последнего ответа
              $timeSinceLastResponse = ($currentTime - $server.LastResponseTime).TotalSeconds

              if ($timeSinceLastResponse -gt $HangTimeout) {
                  # Сервер считается зависшим
                  Write-Host "  Сервер $($server.Name) не отвечает в течение $([Math]::Round($timeSinceLastResponse)) секунд. Будет выполнен принудительный перезапуск." -ForegroundColor Red
                  $hangingServers += $server
              } else {
                  Write-DebugLog "Сервер $($server.Name) не отвечает в течение $([Math]::Round($timeSinceLastResponse)) секунд (порог: $HangTimeout)." -Color "Yellow"
              }
          }
      }
  }

  # Возвращаем список зависших серверов
  return $hangingServers
}

# Обновим функцию Prepare-ServerDataFiles, чтобы она использовала шаблон user.ltx из папки templates

function Prepare-ServerDataFiles {
param (
    [PSCustomObject]$Server,
    [string]$ServersDataPath,
    [string]$TemplatesPath
)

# Полный путь к папке с данными сервера
$serverDataPath = Join-Path -Path $ServersDataPath -ChildPath "$($Server.ConfigPrefix)_server"
Write-DebugLog "Подготовка файлов для сервера $($Server.Name) (ConfigPrefix: $($Server.ConfigPrefix))" -Color "Magenta"
Write-DebugLog "Путь к данным сервера: $serverDataPath" -Color "Magenta"

# Проверка и создание папки сервера, если она не существует
if (-not (Test-Path -Path $serverDataPath)) {
    Write-Host "    Создание папки для данных сервера: $serverDataPath" -ForegroundColor Gray
    New-Item -Path $serverDataPath -ItemType Directory -Force | Out-Null
}
else {
    Write-DebugLog "Папка для данных сервера уже существует: $serverDataPath" -Color "Green"
}

# Путь к файлу user.ltx
$userLtxPath = Join-Path -Path $serverDataPath -ChildPath "user.ltx"

# Путь к шаблону user.ltx
$userLtxTemplatePath = Join-Path -Path $TemplatesPath -ChildPath "user.ltx"

# Проверка и создание файла user.ltx, если он не существует
if (-not (Test-Path -Path $userLtxPath)) {
    Write-Host "    Создание файла user.ltx" -ForegroundColor Gray
    Write-DebugLog "Создание файла user.ltx: $userLtxPath" -Color "Magenta"

    # Проверяем, существует ли шаблон
    if (Test-Path -Path $userLtxTemplatePath) {
        # Копируем шаблон
        Copy-Item -Path $userLtxTemplatePath -Destination $userLtxPath
        Write-DebugLog "Файл user.ltx создан из шаблона: $userLtxTemplatePath" -Color "Green"
    } else {
        Write-Host "    ВНИМАНИЕ: Шаблон user.ltx не найден: $userLtxTemplatePath" -ForegroundColor Yellow
        Write-DebugLog "Шаблон user.ltx не найден: $userLtxTemplatePath. Создание пустого файла." -Color "Yellow"
        "" | Set-Content -Path $userLtxPath -Encoding UTF8
    }
}
else {
    Write-DebugLog "Файл user.ltx уже существует: $userLtxPath" -Color "Green"
}

# Создание пустых файлов banned_list.ltx и banned_list_ip.ltx
$bannedListPath = Join-Path -Path $serverDataPath -ChildPath "banned_list.ltx"
$bannedListIpPath = Join-Path -Path $serverDataPath -ChildPath "banned_list_ip.ltx"

if (-not (Test-Path -Path $bannedListPath)) {
    Write-Host "    Создание файла banned_list.ltx" -ForegroundColor Gray
    Write-DebugLog "Создание файла banned_list.ltx: $bannedListPath" -Color "Magenta"
    "" | Set-Content -Path $bannedListPath -Encoding UTF8
}
else {
    Write-DebugLog "Файл banned_list.ltx уже существует: $bannedListPath" -Color "Green"
}

if (-not (Test-Path -Path $bannedListIpPath)) {
    Write-Host "    Создание файла banned_list_ip.ltx" -ForegroundColor Gray
    Write-DebugLog "Создание файла banned_list_ip.ltx: $bannedListIpPath" -Color "Magenta"
    "" | Set-Content -Path $bannedListIpPath -Encoding UTF8
}
else {
    Write-DebugLog "Файл banned_list_ip.ltx уже существует: $bannedListIpPath" -Color "Green"
}

# Создание файла radmins.ltx если у сервера есть записи в radmins
if ($Server.Radmins.Count -gt 0) {
    $radminsPath = Join-Path -Path $serverDataPath -ChildPath "radmins.ltx"

    Write-Host "    Создание файла radmins.ltx" -ForegroundColor Gray
    Write-DebugLog "Создание файла radmins.ltx: $radminsPath" -Color "Magenta"
    Write-DebugLog "Количество радминов: $($Server.Radmins.Count)" -Color "Magenta"

    # Начало файла radmins.ltx
    $radminsContent = "[radmins]"

    # Добавление записей радминов
    foreach ($radmin in $Server.Radmins) {
        $radminsContent += "`n$radmin"
    }

    # Запись содержимого в файл
    $radminsContent | Set-Content -Path $radminsPath -Encoding UTF8
}
else {
    Write-DebugLog "У сервера $($Server.Name) нет радминов, файл radmins.ltx не создается" -Color "Yellow"
}

return $serverDataPath
}

# Функция для поиска окон серверов по PID процессов и характеристикам окна
function Find-ServerWindowsByPID {
  # Создаем массив для хранения найденных окон STALKER
  $script:stalkerWindows = @()

  # Функция обратного вызова для EnumWindows
  $callbackScript = {
      param(
          [IntPtr]$hwnd,
          [IntPtr]$lParam
      )

      # Проверяем, видимое ли окно
      if (-not [Win32]::IsWindowVisible($hwnd)) {
          return $true
      }

      # Получаем ID процесса
      $processId = Get-WindowProcessId -hwnd $hwnd

      # Получаем класс окна
      $windowClass = Get-WindowClass -hwnd $hwnd

      # Получаем заголовок окна
      $windowTitle = Get-WindowTitle -hwnd $hwnd

      # Получаем размер и позицию окна
      $rect = Get-WindowRect -hwnd $hwnd
      $windowWidth = $rect.Right - $rect.Left
      $windowHeight = $rect.Bottom - $rect.Top

      # Проверяем, является ли окно окном сервера STALKER
      $isStalkerServerWindow = $false

      # Проверка по классу окна и заголовку
      if ($windowClass -eq $global:WINDOW_CLASS_NAME -and $windowTitle -like $global:WINDOW_TITLE_PATTERN) {
          $isStalkerServerWindow = $true

          # Создаем объект с информацией об окне
          $windowInfo = [PSCustomObject]@{
              Handle = $hwnd
              Class = $windowClass
              Title = $windowTitle
              Left = $rect.Left
              Top = $rect.Top
              Width = $windowWidth
              Height = $windowHeight
              ProcessId = $processId
          }

          # Добавляем окно в массив окон STALKER
          $script:stalkerWindows = $script:stalkerWindows + $windowInfo

          Write-DebugLog "Найдено окно STALKER: PID=$processId, Handle=$hwnd, Class=$windowClass, Title='$windowTitle', Size=$windowWidth x $windowHeight" -Color "Green"
      } else {
          Write-DebugLog "Найдено окно: PID=$processId, Handle=$hwnd, Class=$windowClass, Title='$windowTitle', Size=$windowWidth x $windowHeight" -Color "Gray"
      }

      return $true
  }

  # Создаем делегат для функции обратного вызова
  $enumWindowsCallback = [Win32+EnumWindowsProc]$callbackScript

  Write-DebugLog "Начало поиска окон процессов..." -Color "Magenta"

  # Перечисляем все окна
  [void][Win32]::EnumWindows($enumWindowsCallback, [IntPtr]::Zero)

  # Выводим информацию о найденных окнах STALKER
  Write-DebugLog "Найдено окон STALKER: $($stalkerWindows.Count)" -Color "Magenta"

  # Если найдены окна STALKER, пытаемся сопоставить их с серверами
  if ($stalkerWindows.Count -gt 0) {
      # Выводим информацию о процессах серверов
      Write-DebugLog "Информация о процессах серверов:" -Color "Magenta"

      # Сначала пытаемся найти окна по PID процессов серверов
      for ($i = 0; $i -lt $global:ServersList.Count; $i++) {
          $server = $global:ServersList[$i]
          if ($null -ne $server.Process) {
              $procId = $server.Process.Id
              Write-DebugLog "Сервер $($server.Name): ProcessId=${procId}, HasExited=$($server.Process.HasExited)" -Color "Magenta"

              # Получаем командную строку процесса
              $cmdLine = Get-ProcessCommandLine -processId $procId
              Write-DebugLog "Командная строка: $cmdLine" -Color "Magenta"

              # Проверяем, есть ли окна STALKER для этого процесса
              $serverWindows = $stalkerWindows | Where-Object { $_.ProcessId -eq $procId }

              if ($null -ne $serverWindows -and $serverWindows.Count -gt 0) {
                  Write-DebugLog "Найдено окон STALKER для процесса ${procId}: $($serverWindows.Count)" -Color "Green"

                  # Если найдено несколько окон, выбираем самое большое
                  $mainWindow = $serverWindows | Sort-Object Width, Height -Descending | Select-Object -First 1
                  Write-DebugLog "Основное окно: Handle=$($mainWindow.Handle), Size=$($mainWindow.Width) x $($mainWindow.Height)" -Color "Green"

                  # Сохраняем дескриптор окна в объекте сервера
                  $global:ServersList[$i].WindowHandle = $mainWindow.Handle
              } else {
                  Write-DebugLog "Не найдено окон STALKER для процесса ${procId}" -Color "Yellow"
              }
          } else {
              Write-DebugLog "Сервер $($server.Name): Process=null" -Color "Magenta"
          }
      }

      # Если не все серверы получили окна, распределяем оставшиеся окна STALKER
      $serversWithoutWindows = $global:ServersList | Where-Object { $null -eq $_.WindowHandle -and $null -ne $_.Process -and -not $_.Process.HasExited }
      $remainingStalkerWindows = $stalkerWindows | Where-Object {
          $windowHandle = $_.Handle
          -not ($global:ServersList | Where-Object { $_.WindowHandle -eq $windowHandle })
      }

      Write-DebugLog "Серверов без окон: $($serversWithoutWindows.Count), Оставшихся окон STALKER: $($remainingStalkerWindows.Count)" -Color "Magenta"

      # Распределяем оставшиеся окна STALKER по серверам без окон
      for ($i = 0; $i -lt [Math]::Min($serversWithoutWindows.Count, $remainingStalkerWindows.Count); $i++) {
          $server = $serversWithoutWindows[$i]
          $window = $remainingStalkerWindows[$i]

          # Находим индекс сервера в глобальном списке
          $serverIndex = $global:ServersList.IndexOf($server)

          Write-DebugLog "Назначение окна Handle=$($window.Handle) серверу $($server.Name)" -Color "Yellow"
          $global:ServersList[$serverIndex].WindowHandle = $window.Handle
      }
  } else {
      Write-DebugLog "Не найдено окон STALKER!" -Color "Red"
  }
}

# Функция для создания конфигурационного файла сервера
function Create-ServerConfig {
param (
    [string]$ServerConfigPrefix,
    [string]$GamePath,
    [string]$ServersDataPath
)

# Путь к исходному файлу fsgame_s.ltx
$fsgameSourcePath = Join-Path -Path $GamePath -ChildPath "fsgame_s.ltx"

# Проверка существования исходного файла
if (-not (Test-Path -Path $fsgameSourcePath)) {
    Write-Host "ОШИБКА: Не найден файл fsgame_s.ltx: $fsgameSourcePath" -ForegroundColor Red
    return $false
}

# Путь к целевому файлу конфигурации
$configTargetPath = Join-Path -Path $GamePath -ChildPath "$ServerConfigPrefix`_server.ltx"

# Путь к данным сервера
$serverDataPath = Join-Path -Path $ServersDataPath -ChildPath "$ServerConfigPrefix`_server"

# Создание директории для данных сервера, если она не существует
if (-not (Test-Path -Path $serverDataPath)) {
    New-Item -Path $serverDataPath -ItemType Directory -Force | Out-Null
    Write-Host "Создана директория для данных сервера: $serverDataPath" -ForegroundColor Green
}

try {
    # Чтение содержимого исходного файла
    $content = Get-Content -Path $fsgameSourcePath -Raw

    # Получаем полные пути
    $fullGamePath = (Resolve-Path $GamePath).Path
    $fullServerDataPath = (Resolve-Path $serverDataPath).Path

    Write-DebugLog "Полный путь к игре: $fullGamePath" -Color "Magenta"
    Write-DebugLog "Полный путь к данным сервера: $fullServerDataPath" -Color "Magenta"

    # Проверяем, находятся ли пути на одном диске
    $gamePathDrive = Split-Path -Qualifier $fullGamePath
    $serverDataPathDrive = Split-Path -Qualifier $fullServerDataPath

    if ($gamePathDrive -ne $serverDataPathDrive) {
        Write-Host "ОШИБКА: Папка игры и папка данных сервера должны находиться на одном диске!" -ForegroundColor Red
        return $false
    }

    # Вычисляем относительный путь от GamePath к ServerDataPath
    # Используем более надежный метод
    $relativePath = ""

    # Разбиваем пути на компоненты
    $gamePathParts = $fullGamePath.Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) | Where-Object { $_ -ne "" }
    $serverDataPathParts = $fullServerDataPath.Split([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) | Where-Object { $_ -ne "" }

    # Находим общий префикс
    $commonPrefixLength = 0
    $minLength = [Math]::Min($gamePathParts.Length, $serverDataPathParts.Length)

    for ($i = 0; $i -lt $minLength; $i++) {
        if ($gamePathParts[$i] -eq $serverDataPathParts[$i]) {
            $commonPrefixLength++
        } else {
            break
        }
    }

    # Строим относительный путь
    $upCount = $gamePathParts.Length - $commonPrefixLength
    $downParts = $serverDataPathParts[$commonPrefixLength..($serverDataPathParts.Length - 1)]

    # Добавляем ".." для каждого уровня вверх
    for ($i = 0; $i -lt $upCount; $i++) {
        $relativePath += ".." + [IO.Path]::DirectorySeparatorChar
    }

    # Добавляем компоненты пути вниз
    $relativePath += [string]::Join([IO.Path]::DirectorySeparatorChar, $downParts)

    # Добавляем обратный слеш в конец пути, если его нет
    if (-not $relativePath.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $relativePath += [IO.Path]::DirectorySeparatorChar
    }

    Write-DebugLog "Вычисленный относительный путь: $relativePath" -Color "Green"

    # Замена пути к данным сервера
    $content = $content -replace "_appdata_server\\", $relativePath

    # Сохранение измененного содержимого в целевой файл
    $content | Set-Content -Path $configTargetPath -Encoding UTF8

    Write-Host "Создан конфигурационный файл сервера: $configTargetPath" -ForegroundColor Green
    return $true
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Host "ОШИБКА при создании конфигурационного файла сервера: $errorMsg" -ForegroundColor Red
    return $false
}
}

# Функция для запуска сервера (без позиционирования окна)
function Start-Server {
  param (
      [PSCustomObject]$Server,
      [string]$GamePath,
      [string]$BinPath,
      [string]$ServersDataPath
  )

  # Проверка существования конфигурационного файла
  $configPath = Join-Path -Path $GamePath -ChildPath "$($Server.ConfigPrefix)_server.ltx"
  if (-not (Test-Path -Path $configPath)) {
      Write-Host "Конфигурационный файл не найден: $configPath" -ForegroundColor Yellow

      Write-Host "Попытка создать конфигурационный файл..." -ForegroundColor Yellow

      # Создание конфигурационного файла
      $configCreated = Create-ServerConfig -ServerConfigPrefix $Server.ConfigPrefix -GamePath $GamePath -ServersDataPath $ServersDataPath

      if (-not $configCreated) {
          Write-Host "ОШИБКА: Не удалось создать конфигурационный файл сервера." -ForegroundColor Red
          return $null
      }
  }

  # Формирование аргументов командной строки для запуска сервера
  $processArgs = @(
      "-i",                                      # Игнорировать ошибки
      "-silent_error_mode",                      # Тихий режим ошибок
      "-fsltx",                                  # Указание файла конфигурации
      "..\$($Server.ConfigPrefix)_server.ltx",   # Путь к файлу конфигурации относительно bin (в родительской директории)
      "-noprefetch",                             # Отключение предзагрузки
      "-auto_affinity",                          # Автоматическое распределение нагрузки на ядра
      "-start",                                  # Команда запуска
      # Параметры сервера: карта, имя, публичность, максимум игроков, порты
      "server(df_derevnya/df/hname=$($Server.Name)/public=1/maxplayers=4/portsv=$($Server.Port)/portgs=$($Server.Port+1)/portcl=$($Server.Port+2))",
      "client(localhost)"                        # Клиентское подключение
  )

  # Запуск процесса сервера с указанием рабочей директории bin
  try {
      # Используем путь к xrEngine.exe относительно bin
      Write-DebugLog "Запуск сервера $($Server.Name) с аргументами: $processArgs" -Color "Magenta"
      $process = Start-Process -FilePath "dedicated\xrEngine.exe" -ArgumentList $processArgs -WorkingDirectory $BinPath -PassThru
      Write-DebugLog "Сервер $($Server.Name) запущен, ProcessId=$($process.Id)" -Color "Magenta"
      return $process
  }
  catch {
      $errorMsg = $_.Exception.Message
      Write-Host "ОШИБКА при запуске сервера $($Server.Name): $errorMsg" -ForegroundColor Red
      return $null
  }
}

# Функция для позиционирования окон всех серверов (только перемещение, без изменения размера и без активации окна)
function Position-ServerWindows {
  param (
      [array]$ServerPositions
  )

  # Если сервер только один, не меняем его положение
  if ($global:ServersList.Count -le 1) {
      Write-Host "  Сервер только один, оставляем его положение без изменений" -ForegroundColor Gray
      return
  }

  # Ожидание появления окон серверов
  Write-Host "  Ожидание появления окон серверов..." -ForegroundColor Gray
  Start-Sleep -Seconds $global:WINDOW_SEARCH_DELAY

  # Обновляем информацию о окнах серверов
  Find-ServerWindowsByPID

  # Подсчитываем количество серверов с найденными окнами
  $serversWithWindows = $global:ServersList | Where-Object { $null -ne $_.WindowHandle } | Measure-Object
  $windowCount = $serversWithWindows.Count

  if ($windowCount -gt 0) {
      Write-Host "  Найдено окон серверов: $windowCount" -ForegroundColor Gray

      # Позиционирование окон
      $positionIndex = 0
      for ($i = 0; $i -lt $global:ServersList.Count; $i++) {
          $server = $global:ServersList[$i]
          if ($null -ne $server.WindowHandle) {
              $hwnd = $server.WindowHandle
              $position = $ServerPositions[$positionIndex]
              $positionIndex++

              # Получение текущего размера и позиции окна
              $rectBefore = Get-WindowRect -hwnd $hwnd
              $windowWidth = $rectBefore.Right - $rectBefore.Left
              $windowHeight = $rectBefore.Bottom - $rectBefore.Top

              Write-DebugLog "Перемещение окна сервера $($server.Name): Handle=$hwnd, Текущая позиция=($($rectBefore.Left),$($rectBefore.Top)), Размер=($($windowWidth)x$($windowHeight))" -Color "Magenta"
              Write-DebugLog "Новая позиция: X=$($position.X), Y=$($position.Y)" -Color "Magenta"

              # Перемещаем окно
              Move-Window -WindowHandle $hwnd -X ([int]$position.X) -Y ([int]$position.Y) -Width $windowWidth -Height $windowHeight
          }
      }
  } else {
      Write-Host "  Не найдено окон серверов" -ForegroundColor Yellow
  }
}

# Функция для мониторинга серверов
function Monitor-Servers {
  param (
      [string]$GamePath,
      [string]$BinPath,
      [string]$ServersDataPath,
      [string]$ConfigFile,
      [int]$ServerHangTimeout,
      [string]$DiscordWebhookUrl,
      [int]$RestartNotificationThreshold,
      [string]$TemplatesPath
  )

  # Расчет позиций окон
  $windowLayout = Calculate-WindowPositions -ServerCount $global:ServersList.Count
  $positions = $windowLayout.Positions

  Write-Host "  Расположение окон: $($windowLayout.Columns) столбцов x $($windowLayout.Rows) строк" -ForegroundColor Gray

  # Счетчик для периодического позиционирования окон
  $positionCounter = 0

  while ($true) {
      Clear-Host
      Write-Host "`n  Статус Серверов:`n" -ForegroundColor Cyan
      Write-Host "  Путь к игре: $GamePath" -ForegroundColor Gray
      Write-Host "  Путь к данным серверов: $ServersDataPath" -ForegroundColor Gray
      Write-Host "  Файл конфигурации: $ConfigFile" -ForegroundColor Gray
      Write-Host "  Расположение окон: $($windowLayout.Columns) столбцов x $($windowLayout.Rows) строк" -ForegroundColor Gray
      Write-Host ""

      $totalRestarts = 0
      $needsPositioning = $false

      # Проверка зависших серверов
      $hangingServers = Check-HangingServers -HangTimeout $ServerHangTimeout

      # Принудительное завершение зависших серверов
      foreach ($server in $hangingServers) {
          Write-Host "  Принудительное завершение зависшего сервера $($server.Name)..." -ForegroundColor Red
          try {
              if ($null -ne $server.Process -and -not $server.Process.HasExited) {
                  Stop-Process -Id $server.Process.Id -Force -ErrorAction Stop
                  Write-Host "  Сервер $($server.Name) успешно завершен." -ForegroundColor Green

                  # Находим индекс сервера в глобальном списке
                  $serverIndex = $global:ServersList.IndexOf($server)
                  $global:ServersList[$serverIndex].Process = $null
                  $global:ServersList[$serverIndex].WindowHandle = $null
              }
          }
          catch {
              Write-Host "  Ошибка при завершении сервера $($server.Name): $($_.Exception.Message)" -ForegroundColor Red
          }
      }

      for ($i = 0; $i -lt $global:ServersList.Count; $i++) {
          $server = $global:ServersList[$i]

          Write-Host "  Сервер $($server.Name):" -ForegroundColor Yellow

          # Проверка, работает ли сервер
          if ($null -eq $server.Process -or $server.Process.HasExited) {
              Write-Host "    Статус: " -NoNewline
              Write-Host "Не работает. Перезапуск..." -ForegroundColor Red

              # Обновляем файл radmins.ltx перед запуском сервера
              Prepare-ServerDataFiles -Server $server -ServersDataPath $ServersDataPath -TemplatesPath $TemplatesPath

              # Перезапуск сервера
              $process = Start-Server -Server $server -GamePath $GamePath -BinPath $BinPath -ServersDataPath $ServersDataPath
              if ($null -ne $process) {
                  $global:ServersList[$i].Process = $process
                  $global:ServersList[$i].Restarts = $server.Restarts + 1
                  $global:ServersList[$i].WindowHandle = $null  # Сбрасываем дескриптор окна
                  $global:ServersList[$i].LastResponseTime = Get-Date  # Сбрасываем время последнего ответа
                  $needsPositioning = $true

                  # Проверка, нужно ли отправить уведомление о перезапуске
                  if ($global:ServersList[$i].Restarts -ge $RestartNotificationThreshold) {
                      # Отправляем уведомление только если количество перезапусков кратно порогу или это первое превышение порога
                      if ($global:ServersList[$i].Restarts % $RestartNotificationThreshold -eq 0 || $global:ServersList[$i].Restarts -eq $RestartNotificationThreshold) {
                          $message = "Сервер $($server.Name) был перезапущен $($global:ServersList[$i].Restarts) раз(а). Последний перезапуск: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                          Write-Host "    Отправка уведомления в Discord..." -ForegroundColor Magenta

                          # Отправка уведомления в Discord
                          $notificationSent = Send-DiscordNotification -WebhookUrl $DiscordWebhookUrl -Message $message -Title "Уведомление о перезапуске сервера STALKER"

                          if ($notificationSent) {
                              Write-Host "    Уведомление отправлено." -ForegroundColor Green
                          }
                      }
                  }

                  # Даем серверу время на создание окна
                  Write-Host "    Ожидание создания окна сервера..." -ForegroundColor Yellow
                  Start-Sleep -Seconds $global:SERVER_STARTUP_DELAY
              } else {
                  Write-Host "    ОШИБКА: Не удалось перезапустить сервер!" -ForegroundColor Red
              }
          } else {
              Write-Host "    Статус: " -NoNewline
              Write-Host "Работает" -ForegroundColor Green
          }

          Write-Host "    Перезапуски: $($server.Restarts)"
          Write-Host ""

          $totalRestarts += $server.Restarts
      }

      Write-Host "  Общее количество перезапусков: $totalRestarts" -ForegroundColor Magenta
      Write-Host "  Нажмите Ctrl+C для выхода" -ForegroundColor Gray

      # Периодическое позиционирование окон или после перезапуска
      $positionCounter++
      if ($needsPositioning) {
          # Немедленное позиционирование после перезапуска
          if ($global:ServersList.Count -gt 1) {
              Write-Host "  Позиционирование окон серверов после перезапуска..." -ForegroundColor Yellow
              # Обновляем информацию о окнах серверов
              Find-ServerWindowsByPID
              Position-ServerWindows -ServerPositions $positions
          }
          $positionCounter = 0
      } elseif ($positionCounter -ge $global:MONITOR_POSITION_INTERVAL) { # Каждые ~60 секунд
          if ($global:ServersList.Count -gt 1) {
              Write-Host "  Периодическое позиционирование окон серверов..." -ForegroundColor Gray
              Position-ServerWindows -ServerPositions $positions
          }
          $positionCounter = 0
      }

      # Пауза перед следующей проверкой
      Start-Sleep -Seconds $global:MONITOR_CHECK_INTERVAL
  }
}

