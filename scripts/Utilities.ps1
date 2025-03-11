# Utilities.ps1
# Вспомогательные функции (логирование, расчет позиций окон и т.д.)

# Функция для записи отладочной информации
function Write-DebugLog {
  param (
      [string]$Message,
      [string]$Color = "Gray"
  )
  
  # Получаем текущую дату и время
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  
  # Формируем сообщение с временной меткой
  $logMessage = "[$timestamp] $Message"
  
  # Если отладка включена, выводим сообщение в консоль
  if ($global:DebugEnabled) {
      Write-Host "  [DEBUG] $Message" -ForegroundColor $Color
      
      # Записываем сообщение в файл
      try {
          Add-Content -Path $global:DebugLogFile -Value $logMessage -Encoding UTF8
      }
      catch {
          Write-Host "  Ошибка при записи в файл отладки: $($_.Exception.Message)" -ForegroundColor Red
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
      
      Write-DebugLog "Позиция для сервера $($i+1): X=$x, Y=$y, Width=$cellWidth, Height=$cellHeight" -Color "Magenta"
  }
  
  return @{
      Positions = $positions
      Columns = $columns
      Rows = $rows
  }
}

