$start_location = (Get-Location).Path

Set-Location $PSScriptRoot
. ".\Mole.ps1"
Import-Module ".\powershellMarkdown.dll"
Set-Location $start_location


Export-ModuleMember -Function @(
  'Sync-Mole',
  'Publish-Mole',
  'Initialize-Mole'
 ) 

Write-Host "Mole ready." -ForegroundColor Green 