# Windows PowerShell uninstall script for Voice Recorder
param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Voice Recorder Global Uninstaller for Windows

Usage:
    .\uninstall_global.ps1

This script will:
- Remove %USERPROFILE%\.voice-recorder\ directory
- Remove voice-recorder commands
- Clean up PATH entries

Note: PATH modifications are left intact (you can remove manually if needed)
"@
    exit 0
}

Write-Host "🗑️ Uninstalling Voice Recorder..." -ForegroundColor Red

$globalDir = "$env:USERPROFILE\.voice-recorder"

# Remove global directory
if (Test-Path $globalDir) {
    Write-Host "📁 Removing $globalDir" -ForegroundColor Yellow
    try {
        Remove-Item -Path $globalDir -Recurse -Force
        Write-Host "   ✅ Directory removed successfully"
    } catch {
        Write-Host "   ❌ Error removing directory: $_" -ForegroundColor Red
        Write-Host "   You may need to close any running voice-recorder processes first" -ForegroundColor Yellow
    }
} else {
    Write-Host "📁 Directory $globalDir not found, nothing to remove" -ForegroundColor Gray
}

# Check for and remove any remaining command files in system directories
$systemPaths = @(
    "$env:USERPROFILE\.voice-recorder\voice-recorder.bat",
    "$env:USERPROFILE\.voice-recorder\voice-recorder.ps1"
)

foreach ($path in $systemPaths) {
    if (Test-Path $path) {
        Write-Host "⚙️ Removing command file: $path" -ForegroundColor Yellow
        try {
            Remove-Item -Path $path -Force
            Write-Host "   ✅ Removed successfully"
        } catch {
            Write-Host "   ❌ Error removing: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "✅ Uninstall complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Note: PATH modifications are left intact" -ForegroundColor Yellow
Write-Host "   If you want to clean up PATH, manually remove:" -ForegroundColor Gray
Write-Host "   $globalDir" -ForegroundColor Gray
Write-Host ""
Write-Host "🔄 You may need to restart your terminal for changes to take effect" -ForegroundColor Yellow