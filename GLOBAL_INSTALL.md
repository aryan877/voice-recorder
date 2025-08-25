# Global Voice Recorder Installation

## Quick Install

### macOS/Linux
```bash
chmod +x install_global.sh
./install_global.sh
```

### Windows
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install_global.ps1
```

## Usage

After installation, you can use the voice recorder from **any directory**:

```bash
voice-recorder
```

## Features

- **Global access**: Use from any Cursor project or terminal
- **Hotkey**: Cmd+` to start/stop recording
- **Auto-transcription**: Uses your Azure OpenAI or OpenAI API
- **Cost tracking**: Logs usage and costs to `~/.voice-recorder/voice_recorder_usage.jsonl`
- **Smart pasting**: Automatically pastes transcribed text

## Configuration

### macOS/Linux
```bash
nano ~/.voice-recorder/.env
```

### Windows
```powershell
notepad "$env:USERPROFILE\.voice-recorder\.env"
```

## View Usage Logs

### macOS/Linux
```bash
cat ~/.voice-recorder/voice_recorder_usage.jsonl | jq
```

### Windows
```powershell
Get-Content "$env:USERPROFILE\.voice-recorder\voice_recorder_usage.jsonl" | ConvertFrom-Json
```

## Uninstall

### macOS/Linux
```bash
chmod +x uninstall_global.sh
./uninstall_global.sh
```

### Windows
```powershell
.\uninstall_global.ps1
```

## What it does

### macOS/Linux
1. Installs voice recorder to `~/.voice-recorder/`
2. Creates global `voice-recorder` command
3. Adds to PATH if needed
4. Preserves your API keys and settings
5. Creates usage logs in global location

### Windows
1. Installs voice recorder to `%USERPROFILE%\.voice-recorder\`
2. Creates global `voice-recorder` command (batch and PowerShell)
3. Adds to PATH if needed
4. Preserves your API keys and settings
5. Creates usage logs in global location

Perfect for developers who want voice-to-text in any project! 🎉