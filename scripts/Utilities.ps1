# Utilities.ps1
# Вспомогательные функции (логирование, расчет позиций окон и т.д.)

# Функция для записи отладочной информации
function Write-DebugLog {
param (
    [string]$Message,
    [string]$Color = "Gray",
    [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "VERBOSE")]
    [string]$Level = "INFO"
)

# Получаем текущую дату и время
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Формируем сообщение с временной меткой и уровнем
$logMessage = "[$timestamp][$Level] $Message"

# Если отладка включена, выводим сообщение в консоль
if ($global:DebugEnabled) {
    # Для VERBOSE уровня выводим сообщения только в файл, но не в консоль
    if ($Level -ne "VERBOSE") {
        Write-Host "  [DEBUG][$Level] $Message" -ForegroundColor $Color
    }
    
    # Проверяем, что путь к файлу лога существует
    if (-not [string]::IsNullOrEmpty($global:DebugLogFile)) {
        try {
            # Проверяем, существует ли директория для файла лога
            $logDir = Split-Path -Parent $global:DebugLogFile
            if (-not (Test-Path -Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Записываем сообщение в файл
            Add-Content -Path $global:DebugLogFile -Value $logMessage -Encoding UTF8
        }
        catch {
            Write-Host "  Ошибка при записи в файл отладки: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Путь к файлу отладки не указан" -ForegroundColor Red
    }
}
}

# Функция для расчета оптимального расположения окон на экране
function Calculate-WindowPositions {
param (
    [int]$ServerCount
)

# Получение рабочей области экрана
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$workingArea = $screen.WorkingArea

Write-DebugLog "Рабочая область экрана: X=$($workingArea.X), Y=$($workingArea.Y), Width=$($workingArea.Width), Height=$($workingArea.Height)" -Color "Magenta"

# Максимальное количество столбцов и строк
$maxColumns = 5
$maxRows = 3

# Расчет оптимального количества столбцов и строк
$columns = [Math]::Min([Math]::Ceiling([Math]::Sqrt($ServerCount)), $maxColumns)
$rows = [Math]::Min([Math]::Ceiling($ServerCount / $columns), $maxRows)

# Если серверов больше, чем можно разместить, увеличиваем количество столбцов
if (($columns * $rows) -lt $ServerCount) {
    $columns = [Math]::Min([Math]::Ceiling($ServerCount / $rows), $maxColumns)
}

# Если все еще не хватает места, увеличиваем количество строк (в пределах максимума)
if (($columns * $rows) -lt $ServerCount) {
    $rows = [Math]::Min([Math]::Ceiling($ServerCount / $columns), $maxRows)
}

# Расчет ширины и высоты ячейки
$cellWidth = $workingArea.Width / $columns
$cellHeight = $workingArea.Height / $rows

Write-DebugLog "Расчет позиций: Columns=$columns, Rows=$rows, CellWidth=$cellWidth, CellHeight=$cellHeight" -Color "Magenta"

# Создание массива позиций для каждого сервера
$positions = @()

for ($i = 0; $i -lt $ServerCount; $i++) {
    $col = $i % $columns
    $row = [Math]::Floor($i / $columns)
    
    # Если превышено максимальное количество строк, размещаем в последней строке
    if ($row -ge $maxRows) {
        $row = $maxRows - 1
    }
    
    # Расчет координат X и Y
    $x = $workingArea.X + ($col * $cellWidth)
    $y = $workingArea.Y + ($row * $cellHeight)
    
    $positions += @{
        X = $x
        Y = $y
        Width = $cellWidth
        Height = $cellHeight
    }
    
    # Используем VERBOSE уровень для детальной информации о позициях
    Write-DebugLog "Позиция для сервера $($i+1): X=$x, Y=$y, Width=$cellWidth, Height=$cellHeight" -Color "Magenta" -Level "VERBOSE"
}

return @{
    Positions = $positions
    Columns = $columns
    Rows = $rows
}
}

