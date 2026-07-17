<#
.SYNOPSIS
  Protokolliert alle Kindprozesse von nvim (rekursiv) mit Startzeit relativ
  zum Watcher-Start und mit Lebensdauer. Zeigt genau, welcher Prozess kurz
  nach dem nvim-Start auftaucht und wie lange er lebt/haengt.

.WARUM POLLING
  Win32_ProcessStartTrace braeuchte Admin-Rechte. Polling (Get-CimInstance)
  braucht keine und erfasst gerade die LANGlebigen/haengenden Prozesse
  zuverlaessig - und die sind hier der Punkt (ein 60-90s haengender
  Prozess-Spawn ist sekundenlang sichtbar).

.NUTZUNG
  Bevorzugt ueber `:Debug proc watch [seconds]` (oeffnet dies automatisch in
  einem Terminal-Split innerhalb der laufenden nvim-Instanz, deren Kindprozesse
  beobachtet werden sollen).

  Manuell (z.B. um eine ANDERE nvim-Instanz von aussen zu beobachten):
    1. Dieses Fenster oeffnen und starten:
         pwsh -NoProfile -File "<pfad>\watch-nvim-procs.ps1"
       (oder powershell statt pwsh)
    2. In einem ZWEITEN Fenster nvim starten und den Freeze abwarten.
    3. Nach dem Freeze hier Strg+C -> Zusammenfassung (nach Lebensdauer sortiert).

.PARAMETER Seconds
  Wie lange beobachtet wird (Default 120). Strg+C beendet frueher.
.PARAMETER IntervalMs
  Poll-Intervall (Default 150ms).
#>
param(
  [int]$Seconds    = 120,
  [int]$IntervalMs = 150
)

$ErrorActionPreference = 'Stop'
$t0     = [System.Diagnostics.Stopwatch]::StartNew()
$seen   = @{}   # pid -> [pscustomobject] Datensatz
$living = @{}   # pid -> $true, aktuell lebend

Write-Host "Watcher laeuft. Starte jetzt nvim im zweiten Fenster. Strg+C beendet." -ForegroundColor Cyan

# Rekursiv pruefen, ob eine PID von irgendeinem nvim-Prozess abstammt.
function Test-DescendsFromNvim {
  param([int]$TargetPid, [hashtable]$Procs)
  $depth = 0
  $cur = $TargetPid
  while ($cur -and $depth -lt 40) {
    $p = $Procs[$cur]
    if (-not $p) { return $false }
    if ($p.Name -match '^(nvim|nvim-qt)(\.exe)?$') { return $true }
    $cur = [int]$p.ParentProcessId
    $depth++
  }
  return $false
}

try {
  while ($t0.Elapsed.TotalSeconds -lt $Seconds) {
    $snapshot = @{}
    Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId,Name,CommandLine |
      ForEach-Object { $snapshot[[int]$_.ProcessId] = $_ }

    # Neue Prozesse, die vom nvim-Baum abstammen
    foreach ($kv in $snapshot.GetEnumerator()) {
      $procId = $kv.Key
      if ($seen.ContainsKey($procId)) { continue }
      $p = $kv.Value
      if (-not (Test-DescendsFromNvim -TargetPid $procId -Procs $snapshot)) { continue }

      $rec = [pscustomobject]@{
        Pid       = $procId
        PPid      = [int]$p.ParentProcessId
        Name      = $p.Name
        Cmd       = $p.CommandLine
        StartMs   = [math]::Round($t0.Elapsed.TotalMilliseconds)
        EndMs     = $null
        LifeMs    = $null
      }
      $seen[$procId]   = $rec
      $living[$procId] = $true
      Write-Host ("[+{0,7:N0}ms] START pid={1,-6} ppid={2,-6} {3}" -f `
        $rec.StartMs, $rec.Pid, $rec.PPid, $rec.Name) -ForegroundColor Yellow
      if ($rec.Cmd) {
        Write-Host ("             {0}" -f ($rec.Cmd.Substring(0, [Math]::Min(180, $rec.Cmd.Length)))) -ForegroundColor DarkGray
      }
    }

    # Beendete Prozesse -> Lebensdauer festhalten
    foreach ($procId in @($living.Keys)) {
      if (-not $snapshot.ContainsKey($procId)) {
        $rec = $seen[$procId]
        $rec.EndMs  = [math]::Round($t0.Elapsed.TotalMilliseconds)
        $rec.LifeMs = $rec.EndMs - $rec.StartMs
        $living.Remove($procId)
        Write-Host ("[+{0,7:N0}ms] EXIT  pid={1,-6} lebte {2,7:N0}ms  {3}" -f `
          $rec.EndMs, $rec.Pid, $rec.LifeMs, $rec.Name) `
          -ForegroundColor ($(if ($rec.LifeMs -gt 3000) { 'Red' } else { 'Green' }))
      }
    }

    Start-Sleep -Milliseconds $IntervalMs
  }
}
finally {
  Write-Host "`n===== ZUSAMMENFASSUNG (nach Lebensdauer absteigend) =====" -ForegroundColor Cyan
  $now = [math]::Round($t0.Elapsed.TotalMilliseconds)
  $seen.Values |
    ForEach-Object {
      if ($null -eq $_.LifeMs) { $_.LifeMs = $now - $_.StartMs; $_.EndMs = 'laeuft noch' }
      $_
    } |
    Sort-Object LifeMs -Descending |
    Select-Object @{N='LifeMs';E={$_.LifeMs}},
                  @{N='StartMs';E={$_.StartMs}},
                  Name, Pid, PPid,
                  @{N='Cmd';E={ if ($_.Cmd) { $_.Cmd.Substring(0,[Math]::Min(120,$_.Cmd.Length)) } }} |
    Format-Table -AutoSize -Wrap
  Write-Host "Der oberste Eintrag mit auffaelliger Lebensdauer ist der Freeze-Verursacher." -ForegroundColor Cyan
}
