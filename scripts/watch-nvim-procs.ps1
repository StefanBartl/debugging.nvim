<#
.SYNOPSIS
  Logs every child process of nvim (recursively) with its start time relative
  to the watcher start and its lifetime. Shows exactly which process appears
  shortly after nvim starts and how long it lives/hangs.

.WHY POLLING
  Win32_ProcessStartTrace would need admin rights. Polling (Get-CimInstance)
  needs none and reliably catches exactly the LONG-lived/hanging processes
  that matter here (a 60-90s hanging process spawn is visible for seconds).

.USAGE
  Preferred: via `:Debug proc watch [seconds]` (opens this automatically in a
  terminal split inside the running nvim instance whose child processes are
  to be observed).

  Manual (e.g. to observe a DIFFERENT nvim instance from outside):
    1. Open this window and start:
         pwsh -NoProfile -File "<path>\watch-nvim-procs.ps1"
       (or powershell instead of pwsh)
    2. Start nvim in a SECOND window and wait for the freeze.
    3. After the freeze, Ctrl+C here -> summary (sorted by lifetime).

.PARAMETER Seconds
  How long to observe (default 120). Ctrl+C ends it early.
.PARAMETER IntervalMs
  Poll interval (default 150ms).
#>
param(
  [int]$Seconds    = 120,
  [int]$IntervalMs = 150
)

$ErrorActionPreference = 'Stop'
$t0     = [System.Diagnostics.Stopwatch]::StartNew()
$seen   = @{}   # pid -> [pscustomobject] record
$living = @{}   # pid -> $true, currently alive

Write-Host "Watcher laeuft. Starte jetzt nvim im zweiten Fenster. Strg+C beendet." -ForegroundColor Cyan

# Recursively check whether a PID descends from any nvim process.
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

    # New processes descending from the nvim tree
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

    # Exited processes -> record lifetime
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
