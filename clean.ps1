<#
.SYNOPSIS
  Reset ephemeral sandbox dirs to a fresh state.
.DESCRIPTION
  Removes everything inside workspace/ and .opencode-state/ except .gitkeep.
.EXAMPLE
  .\clean.ps1
  .\clean.ps1 -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Targets = @('workspace', '.opencode-state')

# Warn if the sandbox container is still running against these bind mounts.
$running = ''
try { $running = docker compose --project-directory $Root ps -q 2>$null } catch {}
if ($running) {
  Write-Warning 'agent-sandbox container is running. Consider stopping it first:'
  Write-Warning "  docker compose --project-directory `"$Root`" down"
  if (-not $Force) {
    $answer = Read-Host 'Continue anyway? [y/N]'
    if ($answer -notmatch '^[yY]') { Write-Host 'Aborted.'; exit 1 }
  }
}

if (-not $Force -and -not $WhatIfPreference) {
  Write-Host 'This will delete ALL contents of:'
  foreach ($t in $Targets) { Write-Host "  $Root\$t (except .gitkeep)" }
  $answer = Read-Host 'Continue? [y/N]'
  if ($answer -notmatch '^[yY]') { Write-Host 'Aborted.'; exit 1 }
}

foreach ($t in $Targets) {
  $dir = Join-Path $Root $t
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
  Get-ChildItem -Force $dir -Exclude '.gitkeep' | Remove-Item -Recurse -Force -WhatIf:$WhatIfPreference
  # Keep the dir tracked in git.
  $keep = Join-Path $dir '.gitkeep'
  if (-not (Test-Path $keep)) { New-Item -ItemType File $keep | Out-Null }
  Write-Host "Cleaned $dir"
}

Write-Host 'Done. Fresh workspace + state ready.'
