# Envoltorio de PowerShell. NO reimplementa nada: localiza Git Bash y llama a instalar.sh,
# que es el instalador real y el único que está probado.
#
# ESTADO: NO VERIFICADO. En el contenedor donde se escribió no hay PowerShell,
# así que este envoltorio está revisado a mano pero no ejecutado. Si falla,
# abre "Git Bash" y ejecuta directamente:   ./instalar.sh /c/ruta/al/proyecto
param(
  [Parameter(Mandatory=$true)][string]$Proyecto,
  [switch]$Simular
)
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$candidatos = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
$bash = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) { $bash = (Get-Command bash.exe -ErrorAction SilentlyContinue).Source }
if (-not $bash) {
  Write-Error "No encuentro bash.exe. Instala Git para Windows (incluye Git Bash) y reintenta."
  exit 1
}
$args = @("$aqui/instalar.sh", $Proyecto)
if ($Simular) { $args += "--simular" }
& $bash @args
exit $LASTEXITCODE
