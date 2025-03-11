# WindowsAPI.ps1
# Модуль с определениями Windows API и функциями для работы с окнами

# Добавление сборки Windows Forms для получения информации об экране
Add-Type -AssemblyName System.Windows.Forms

# Проверка, существует ли уже тип Win32
if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
  # Добавление функций Windows API для управления окнами
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
  
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  
  [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  
  [DllImport("user32.dll", SetLastError = true)]
  public static extern int GetWindowTextLength(IntPtr hWnd);
  
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
  
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  
  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool IsWindowVisible(IntPtr hWnd);
  
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT
  {
      public int Left;
      public int Top;
      public int Right;
      public int Bottom;
  }
}
"@
}

# Функция для получения заголовка окна
function Get-WindowTitle {
  param (
      [IntPtr]$hwnd
  )
  
  $length = [Win32]::GetWindowTextLength($hwnd)
  if ($length -gt 0) {
      $sb = New-Object System.Text.StringBuilder($length + 1)
      [void][Win32]::GetWindowText($hwnd, $sb, $sb.Capacity)
      return $sb.ToString()
  }
  return "[Без заголовка]"
}

# Функция для получения класса окна
function Get-WindowClass {
  param (
      [IntPtr]$hwnd
  )
  
  $sbClass = New-Object System.Text.StringBuilder(256)
  [void][Win32]::GetClassName($hwnd, $sbClass, $sbClass.Capacity)
  return $sbClass.ToString()
}

# Функция для получения размера и позиции окна
function Get-WindowRect {
  param (
      [IntPtr]$hwnd
  )
  
  $rect = New-Object Win32+RECT
  [Win32]::GetWindowRect($hwnd, [ref]$rect)
  return $rect
}

# Функция для получения ID процесса окна
function Get-WindowProcessId {
  param (
      [IntPtr]$hwnd
  )
  
  $processId = 0
  [Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId)
  return $processId
}

# Функция для получения командной строки процесса
function Get-ProcessCommandLine {
  param (
      [int]$processId
  )
  
  try {
      # Используем Get-CimInstance вместо Get-WmiObject для совместимости с PowerShell 7
      $wmiQuery = "SELECT CommandLine FROM Win32_Process WHERE ProcessId = $processId"
      $process = Get-CimInstance -Query $wmiQuery
      return $process.CommandLine
  }
  catch {
      $errorMsg = $_.Exception.Message
      Write-DebugLog "Ошибка при получении командной строки процесса ${processId}: $errorMsg" -Color "Red"
      return $null
  }
}

# Функция для перемещения окна
function Move-Window {
  param (
      [IntPtr]$WindowHandle,
      [int]$X,
      [int]$Y,
      [int]$Width,
      [int]$Height
  )
  
  # Максимальное количество попыток перемещения окна
  $maxAttempts = $global:WINDOW_MOVE_ATTEMPTS
  $attemptCount = 0
  $moveSuccessful = $false
  
  while (-not $moveSuccessful -and $attemptCount -lt $maxAttempts) {
      $attemptCount++
      
      # Перемещаем окно, сохраняя его текущий размер, без предварительной активации
      [void][Win32]::MoveWindow($WindowHandle, $X, $Y, $Width, $Height, $true)
      
      # Проверяем результат
      Start-Sleep -Milliseconds $global:WINDOW_MOVE_DELAY
      $rectAfter = Get-WindowRect -hwnd $WindowHandle
      
      # Проверяем, успешно ли переместилось окно
      if ([Math]::Abs($rectAfter.Left - $X) -le 10 -and [Math]::Abs($rectAfter.Top - $Y) -le 10) {
          $moveSuccessful = $true
          Write-DebugLog "Окно успешно перемещено на указанную позицию (попытка $attemptCount)" -Color "Green"
      } else {
          Write-DebugLog "Попытка $attemptCount`: Окно не переместилось на указанную позицию" -Color "Yellow"
          Write-DebugLog "Ожидаемая позиция: X=$X, Y=$Y" -Color "Yellow"
          Write-DebugLog "Фактическая позиция: X=$($rectAfter.Left), Y=$($rectAfter.Top)" -Color "Yellow"
          
          # Если это не последняя попытка, ждем немного перед следующей попыткой
          if ($attemptCount -lt $maxAttempts) {
              Start-Sleep -Milliseconds $global:WINDOW_MOVE_DELAY
          }
      }
  }
  
  # Выводим итоговый результат
  if (-not $moveSuccessful) {
      Write-DebugLog "ВНИМАНИЕ: Не удалось переместить окно на указанную позицию после $maxAttempts попыток!" -Color "Red"
      Write-DebugLog "Ожидаемая позиция: X=$X, Y=$Y" -Color "Red"
      $rectAfter = Get-WindowRect -hwnd $WindowHandle
      Write-DebugLog "Фактическая позиция: X=$($rectAfter.Left), Y=$($rectAfter.Top)" -Color "Red"
  }
  
  return $moveSuccessful
}

