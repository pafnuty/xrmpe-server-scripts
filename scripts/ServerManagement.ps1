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

# Функция для проверки и создания необходимых файлов сервера
function Prepare-ServerDataFiles {
  param (
      [PSCustomObject]$Server,
      [string]$ServersDataPath
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

  # Проверка и создание файла user.ltx, если он не существует
  if (-not (Test-Path -Path $userLtxPath)) {
      Write-Host "    Создание файла user.ltx" -ForegroundColor Gray
      Write-DebugLog "Создание файла user.ltx: $userLtxPath" -Color "Magenta"
      $userLtxContent = @"
_preset Default
ai_aim_max_angle 0.7854
ai_aim_min_angle 0.19635
ai_aim_min_speed 0.19635
ai_aim_predict_time 0.4
ai_use_old_vision 0
ai_use_torch_dynamic_lights on
default_controls
bind left kLEFT
bind right kRIGHT
bind up kUP
bind down kDOWN
bind forward kW
bind back kS
bind lstrafe kA
bind rstrafe kD
bind llookout kQ
bind rlookout kE
bind jump kSPACE
bind crouch kLCONTROL
bind accel kLSHIFT
bind sprint_toggle kX
bind cam_zoom_in kADD
bind cam_zoom_out kSUBTRACT
bind torch kL
bind night_vision kN
bind show_detector kO
bind wpn_1 k1
bind wpn_2 k2
bind wpn_3 k3
bind wpn_4 k4
bind wpn_5 k5
bind wpn_6 k6
bind artefact k7
bind wpn_next kY
bind wpn_fire mouse1
bind wpn_zoom mouse2
bind wpn_reload kR
bind wpn_func kV
bind wpn_firemode_prev k9
bind wpn_firemode_next k0
bind wpn_safe_mode kZ
bind pause kPAUSE
bind drop kG
bind use kF
bind scores kTAB
bind chat kCOMMA
bind screenshot kF12
bind enter kRETURN
bind quit kESCAPE
bind console kGRAVE
bind inventory kI
bind buy_menu kB
bind team_menu kU
bind active_jobs kP
bind action_wheel kT
bind world_marker mouse3
bind voice_squad kH
bind network_information kMULTIPLY
bind vote_begin kF5
bind vote kF6
bind vote_yes kF7
bind vote_no kF8
bind speech_menu_0 kC
bind speech_menu_1 kZ
bind quick_use_1 kF1
bind quick_use_2 kF2
bind quick_use_3 kF3
bind quick_use_4 kF4
bind quick_load kF9
bind_gpad look_around gpAXIS_RIGHT
bind_gpad move_around gpAXIS_LEFT
bind_gpad jump gpA
bind_gpad crouch_toggle gpB
bind_gpad torch gpRIGHT_STICK
bind_gpad wpn_fire gpAXIS_TRIGGER_RIGHT
bind_gpad wpn_zoom gpAXIS_TRIGGER_LEFT
bind_gpad wpn_reload gpX
bind_gpad use gpY
bind_gpad enter gpSTART
bind_gpad quit gpBACK
bind_gpad inventory gpRIGHT_SHOULDER
bind_gpad active_jobs gpLEFT_SHOULDER
bind_gpad quick_use_1 gpDPAD_UP
bind_gpad quick_use_2 gpDPAD_LEFT
bind_gpad quick_use_3 gpDPAD_RIGHT
bind_gpad quick_use_4 gpDPAD_DOWN
bind_sec enter kNUMPADENTER
cam_inert 0.1
cam_slide_inert 0.
cl_dynamiccrosshair on
cl_mpdemosave 0
con_sensitive 0.15
draw_downloads 0
g_backrun on
g_binded_cameras off
g_bullet_time_factor 3.
g_corpsenum 10
g_crouch_toggle off
g_dynamic_music on
g_eventdelay 0
g_fp_legs off
g_game_difficulty gd_stalker
g_god off
g_no_clip off
g_no_clip_toggle off
g_sleep_time 1
g_tracers_all off
g_unlimitedammo off
gamepad_invert_y off
gamepad_sensor_deadzone 0.005
gamepad_sensor_sens 0.5
gamepad_stick_deadzone 15.
gamepad_stick_sens 0.02
hud_cgt_money_panel on
hud_crosshair on
hud_crosshair_collide off
hud_crosshair_dist off
hud_crosshair_inert off
hud_crosshair_laser off
hud_draw on
hud_fp_zoom on
hud_info on
hud_tune off
hud_weapon on
keypress_on_start 1
mm_mm_net_srv_dedicated off
mm_net_con_publicserver off
mm_net_con_spectator 20
mm_net_con_spectator_on off
mm_net_filter_current_version on
mm_net_filter_empty on
mm_net_filter_full on
mm_net_filter_listen on
mm_net_filter_pass on
mm_net_filter_wo_ff on
mm_net_filter_wo_pass on
mm_net_srv_gamemode st_deathmatch
mm_net_srv_maxplayers 32
mm_net_srv_name Stalker
mm_net_srv_reinforcement_type 1
mm_net_weather_rateofchange 1.
mouse_invert off
mouse_sens 0.12
net_cl_icurvesize 0
net_cl_icurvetype 0
net_cl_interpolation 0.1
net_cl_log_data off
net_cl_update_rate 30
net_compressor_enabled 0
net_compressor_gather_stats 0
net_dbg_dump_export_obj 0
net_dbg_dump_import_obj 0
net_dbg_dump_update_read 0
net_dbg_dump_update_write 0
net_dedicated_sleep 5
net_sv_gpmode 0
net_sv_log_data off
net_sv_pending_lim 3
net_sv_update_rate 30
ph_break_common_factor 0.01
ph_frequency 100.00000
ph_gravity 19.62
ph_iterations 18
ph_rigid_break_weapon_factor 1.
ph_timefactor 1.
ph_tri_clear_disable_count 10
ph_tri_query_ex_aabb_rate 1.3
r1_detail_textures off
r1_dlights on
r1_dlights_clip 40.
r1_fog_luminance 1.1
r1_glows_per_frame 16
r1_lmodel_lerp 0.1
r1_pps_u 0.
r1_pps_v 0.
r1_software_skinning 0
r1_ssa_lod_a 64.
r1_ssa_lod_b 48.
r1_tf_mipbias 0.
r2_aa off
r2_aa_break (0.800000, 0.100000, 0.000000)
r2_aa_kernel 0.5
r2_aa_weight (0.250000, 0.250000, 0.000000)
r2_allow_r1_lights off
r2_detail_bump on
r2_dof -1.250000,1.400000,600.000000
r2_dof_enable on
r2_dof_kernel 5.
r2_dof_sky 30.
r2_exp_donttest_shad off
r2_gi off
r2_gi_clip 0.001
r2_gi_depth 1
r2_gi_photons 16
r2_gi_refl 0.9
r2_gloss_factor 4.
r2_ls_bloom_fast off
r2_ls_bloom_kernel_b 0.7
r2_ls_bloom_kernel_g 3.
r2_ls_bloom_kernel_scale 0.7
r2_ls_bloom_speed 100.
r2_ls_bloom_threshold 0.00001
r2_ls_depth_bias -0.0003
r2_ls_depth_scale 1.00001
r2_ls_dsm_kernel 0.7
r2_ls_psm_kernel 0.7
r2_ls_squality 1.
r2_ls_ssm_kernel 0.7
r2_mblur 0.
r2_parallax_h 0.02
r2_shadow_cascede_old off
r2_shadow_cascede_zcul off
r2_slight_fade 0.5
r2_soft_particles on
r2_soft_water on
r2_ssa_lod_a 64.
r2_ssa_lod_b 48.
r2_ssao st_opt_high
r2_ssao_blur off
r2_ssao_half_data off
r2_ssao_hbao off
r2_ssao_hdao on
r2_ssao_mode ui_mm_hdao
r2_ssao_opt_data off
r2_steep_parallax on
r2_sun on
r2_sun_depth_far_bias -0.00002
r2_sun_depth_far_scale 1.
r2_sun_depth_near_bias 0.00001
r2_sun_depth_near_scale 1.
r2_sun_details off
r2_sun_focus on
r2_sun_lumscale 1.
r2_sun_lumscale_amb 1.
r2_sun_lumscale_hemi 1.
r2_sun_near 20.
r2_sun_near_border 0.75
r2_sun_quality st_opt_medium
r2_sun_shafts st_opt_medium
r2_sun_tsm on
r2_sun_tsm_bias -0.01
r2_sun_tsm_proj 0.3
r2_tf_mipbias 0.
r2_tonemap on
r2_tonemap_adaptation 1.
r2_tonemap_amount 0.7
r2_tonemap_lowlum 0.0001
r2_tonemap_middlegray 1.
r2_volumetric_lights on
r2_wait_sleep 0
r2_zfill off
r2_zfill_depth 0.25
r2em 0.
r3_dynamic_wet_surfaces on
r3_dynamic_wet_surfaces_far 30.
r3_dynamic_wet_surfaces_near 10.
r3_dynamic_wet_surfaces_sm_res 256
r3_gbuffer_opt on
r3_minmax_sm off
r3_msaa st_opt_off
r3_msaa_alphatest st_opt_off
r3_use_dx10_1 off
r3_volumetric_smoke on
r4_enable_tessellation on
r4_wireframe off
r__detail_density 0.3
r__dtex_range 50.
r__geometry_lod 0.75
r__supersample 1
r__tf_aniso 8
r__wallmark_ttl 50.
renderer renderer_r1
rs_always_active off
rs_c_brightness 1.
rs_c_contrast 1.
rs_c_gamma 1.
rs_cam_pos off
rs_detail off
rs_fullscreen off
rs_fxaa st_opt_off
rs_refresh_60hz on
rs_skeleton_update 32
rs_stats off
rs_v_sync off
rs_vis_distance 0.1
slot_0 mp_medkit
slot_1 energy_drink
slot_2 mp_antirad
slot_3 conserva
snd_acceleration on
snd_cache_size 32
snd_efx on
snd_pushtalk on
snd_targets 32
snd_volume_3d_eff 0.
snd_volume_eff 0.
snd_volume_music 0.
snd_volume_voice 0.5
sv_activated_return 0
sv_adm_menu_ban_time ?
sv_anomalies_enabled 1
sv_anomalies_length 3
sv_artefact_respawn_delta 30
sv_artefact_returning_time 45
sv_artefact_spawn_force 0
sv_artefact_stay_time 3
sv_artefacts_count 10
sv_auto_team_balance 0
sv_auto_team_swap 1
sv_bearercantsprint 0
sv_client_reconnect_time 3
sv_console_update_rate 1
sv_cta_runkup_to_arts_div 1
sv_dedicated_server_update_rate 100
sv_df_max_connect_wave 3
sv_dmgblockindicator 1
sv_dmgblocktime 0
sv_dump_online_statistics_period 3
sv_forcerespawn 0
sv_fraglimit 10
sv_friendly_fire 1.
sv_friendly_indicators 0
sv_friendly_names 0
sv_hail_to_winner_time 7
sv_invincible_time 5
sv_max_ping_limit 2000
sv_pda_hunt 1
sv_reinforcement_time 15
sv_remove_actors_corpse 0
sv_remove_all_alive_monsters 0
sv_remove_all_alive_stalkers 0
sv_remove_monster_corpse 0
sv_remove_stalker_corpse 0
sv_remove_weapon 0
sv_rename_mode off
sv_returnplayers 1
sv_rpoint_freeze_time 0
sv_saveconfigs 0
sv_savescreenshots 0
sv_shieldedbases 1
sv_show_player_scores_time 3
sv_spectr_firsteye 1
sv_spectr_freefly 0
sv_spectr_freelook 1
sv_spectr_lookat 1
sv_spectr_teamcamera 1
sv_statistic_collect 1
sv_teamkill_limit 3
sv_teamkill_punish 1
sv_timelimit 0
sv_traffic_optimization_level 0
sv_vote_enabled 254
sv_vote_participants 0
sv_vote_quota 0.51
sv_vote_time 1.
sv_warm_up 0
sv_write_update_bin 0
target_framerate 60
texture_lod 8
time_factor 1.000000
translate_x 0.
translate_y 0.
translate_z -0.3
vid_mode 640x480 (32Hz)
vid_window_mode st_opt_windowed
wpn_aim_toggle 0
"@
      $userLtxContent | Set-Content -Path $userLtxPath -Encoding UTF8
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
  $serverDataPath = "$ServersDataPath$ServerConfigPrefix`_server\"

  # Создание директории для данных сервера, если она не существует
  if (-not (Test-Path -Path $serverDataPath)) {
      New-Item -Path $serverDataPath -ItemType Directory -Force | Out-Null
      Write-Host "Создана директория для данных сервера: $serverDataPath" -ForegroundColor Green
  }

  try {
      # Чтение содержимого исходного файла
      $content = Get-Content -Path $fsgameSourcePath -Raw

      # Замена пути к данным сервера
      $content = $content -replace "_appdata_server\\", $serverDataPath

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
      [int]$RestartNotificationThreshold
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
              Prepare-ServerDataFiles -Server $server -ServersDataPath $ServersDataPath

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

