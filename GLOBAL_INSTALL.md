# Global Voice Recorder Installation

## Quick Install

```bash
chmod +x install_global.sh
./install_global.sh
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

Edit your global config:
```bash
nano ~/.voice-recorder/.env
```

## View Usage Logs

```bash
cat ~/.voice-recorder/voice_recorder_usage.jsonl | jq
```

## Uninstall

```bash
chmod +x uninstall_global.sh
./uninstall_global.sh
```

## What it does

1. Installs voice recorder to `~/.voice-recorder/`
2. Creates global `voice-recorder` command
3. Adds to PATH if needed
4. Preserves your API keys and settings
5. Creates usage logs in global location

Perfect for developers who want voice-to-text in any project! 🎉