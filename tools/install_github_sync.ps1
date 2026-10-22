param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$syncScript = Join-Path $PSScriptRoot 'github_sync.py'
$pythonExe = (Get-Command python -ErrorAction Stop).Source
$pythonWindowless = Join-Path (Split-Path -Parent $pythonExe) 'pythonw.exe'
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder 'The Star Games GitHub Sync.lnk'
$arguments = '"' + $syncScript + '" watch'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
if ((Test-Path -LiteralPath $shortcutPath) -and $shortcut.Arguments -ne $arguments) {
	throw 'A startup shortcut with this name belongs to another folder. Inspect it before replacing it.'
}

if ($Uninstall) {
	& $pythonExe $syncScript stop
	if ($LASTEXITCODE -ne 0) { throw 'Could not stop the GitHub sync watcher.' }
	if (Test-Path -LiteralPath $shortcutPath) {
		Remove-Item -LiteralPath $shortcutPath
	}
	Write-Output 'Automatic GitHub sync has been uninstalled.'
	exit 0
}

if (-not (Test-Path -LiteralPath $pythonWindowless -PathType Leaf)) {
	throw 'pythonw.exe was not found beside Python. Install Python for Windows first.'
}
Get-Command git, gh -ErrorAction Stop | Out-Null
$shortcut.TargetPath = $pythonWindowless
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $projectRoot
$shortcut.Description = 'Publish saved Star Games project changes to GitHub after 30 quiet seconds.'
$shortcut.WindowStyle = 7
$shortcut.Save()
$stopFile = Join-Path $projectRoot '.test_data\github-sync\stop'
if (Test-Path -LiteralPath $stopFile) {
	Remove-Item -LiteralPath $stopFile
}
Start-Process -FilePath $pythonWindowless -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden
Write-Output 'Automatic GitHub sync is enabled now and at Windows sign-in.'
