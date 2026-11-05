# Backwards-compatible entry point. The real script lives at scripts\setup.ps1.
# Usage: .\setup.ps1 [-DryRun]
[CmdletBinding()]
param(
    [switch]$DryRun
)

& "$PSScriptRoot\scripts\setup.ps1" @PSBoundParameters
exit $LASTEXITCODE
