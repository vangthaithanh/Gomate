# Superseded by the pin-centric reset; run the maintained equivalent checks.
param(
 [string]$BaseUrl='http://127.0.0.1:18086/api/v1',
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$MongoDatabase
)
& "$PSScriptRoot/verify-trip-pin-centric-reset.ps1" -BaseUrl $BaseUrl -Database $Database -MongoDatabase $MongoDatabase
