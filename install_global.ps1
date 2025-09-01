# Windows PowerShell install script for Voice Recorder
param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Voice Recorder Global Installer for Windows

Usage:
    .\install_global.ps1

This script will:
- Install voice recorder to %USERPROFILE%\.voice-recorder\
- Create global 'voice-recorder' command  
- Add to PATH if needed
- Create Python virtual environment
- Install required packages

Requirements:
- Python 3.7+ installed and in PATH
- PowerShell execution policy allowing scripts
"@
    exit 0
}

Write-Host "🚀 Installing Voice Recorder globally..." -ForegroundColor Green

# Create global directory
$globalDir = "$env:USERPROFILE\.voice-recorder"
Write-Host "📁 Creating directory: $globalDir" -ForegroundColor Yellow

if (!(Test-Path $globalDir)) {
    New-Item -ItemType Directory -Path $globalDir -Force | Out-Null
}

# Copy files to global location
Write-Host "📁 Copying files to $globalDir" -ForegroundColor Yellow
$filesToCopy = @("voice_recorder.py", "requirements.txt", ".env")

foreach ($file in $filesToCopy) {
    if (Test-Path $file) {
        Copy-Item $file -Destination $globalDir -Force
        Write-Host "   ✅ Copied $file"
    } else {
        Write-Host "   ⚠️  Warning: $file not found, skipping" -ForegroundColor Yellow
    }
}

# Create virtual environment in global location
Write-Host "🐍 Creating global Python environment..." -ForegroundColor Yellow
Set-Location $globalDir

# Check if Python is available
try {
    $pythonVersion = python --version 2>&1
    Write-Host "   Found Python: $pythonVersion"
} catch {
    Write-Host "❌ Error: Python not found in PATH. Please install Python 3.7+ first." -ForegroundColor Red
    exit 1
}

# Create virtual environment
python -m venv venv
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: Failed to create virtual environment" -ForegroundColor Red
    exit 1
}

# Activate virtual environment and install requirements
Write-Host "📦 Installing requirements globally..." -ForegroundColor Yellow

# Check and set execution policy if needed
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted") {
        Write-Host "   Setting execution policy for virtual environment..." -ForegroundColor Yellow
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
} catch {
    Write-Host "   ⚠️  Could not check execution policy, continuing..." -ForegroundColor Yellow
}

# Activate virtual environment (dot-source)
try {
    . ".\venv\Scripts\Activate.ps1"
} catch {
    Write-Host "   ⚠️  PowerShell activation failed, trying alternative method..." -ForegroundColor Yellow
    # Use cmd to activate if PowerShell fails and continue installation
    cmd /c "venv\Scripts\activate.bat && python -m pip install --upgrade pip"
}

# Upgrade pip first
python -m pip install --upgrade pip

if (Test-Path "requirements.txt") {
    python -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Failed to install requirements" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️  Warning: requirements.txt not found, skipping package installation" -ForegroundColor Yellow
}

# Create batch file for Windows command
Write-Host "⚙️ Creating global command..." -ForegroundColor Yellow
$batchContent = @"
@echo off
cd /d "%USERPROFILE%\.voice-recorder"
call venv\Scripts\activate.bat
python voice_recorder.py %*
"@

$batchFile = "$env:USERPROFILE\.voice-recorder\voice-recorder.bat"
$batchContent | Out-File -FilePath $batchFile -Encoding ASCII

# Create PowerShell script as well for better integration
$psContent = @"
Set-Location "$env:USERPROFILE\.voice-recorder"
try { . ".\venv\Scripts\Activate.ps1" } catch {}
python voice_recorder.py `$args
"@

$psFile = "$env:USERPROFILE\.voice-recorder\voice-recorder.ps1"
$psContent | Out-File -FilePath $psFile -Encoding UTF8

# Add to PATH if not already there
Write-Host "🔧 Adding to PATH..." -ForegroundColor Yellow

$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($null -eq $currentPath) {
    $currentPath = ""
}

if ($currentPath -notlike "*$globalDir*") {
    # Ensure proper semicolon separation
    if ($currentPath -and !$currentPath.EndsWith(";")) {
        $newPath = "$currentPath;$globalDir"
    } else {
        $newPath = "$currentPath$globalDir"
    }
    
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "   ✅ Added $globalDir to user PATH"
    Write-Host "   🔄 Restart your terminal for PATH changes to take effect"
} else {
    Write-Host "   ✅ Directory already in PATH"
}

Write-Host ""
Write-Host "✅ Global installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Usage from any directory:" -ForegroundColor Cyan
Write-Host "  voice-recorder" -ForegroundColor White
Write-Host ""
Write-Host "🔧 To update your .env globally:" -ForegroundColor Cyan  
Write-Host "  notepad `"$env:USERPROFILE\.voice-recorder\.env`"" -ForegroundColor White
Write-Host ""
Write-Host "📊 Usage logs will be saved to:" -ForegroundColor Cyan
Write-Host "  $env:USERPROFILE\.voice-recorder\voice_recorder_usage.jsonl" -ForegroundColor White
Write-Host ""
Write-Host "🔄 Restart your terminal or PowerShell session to use the command" -ForegroundColor Yellow

# Return to original directory
Set-Location $PSScriptRoot
