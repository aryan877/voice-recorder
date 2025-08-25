#!/bin/bash

echo "🗑️ Uninstalling Voice Recorder..."

# Remove global directory
if [ -d "$HOME/.voice-recorder" ]; then
    echo "📁 Removing $HOME/.voice-recorder"
    rm -rf "$HOME/.voice-recorder"
fi

# Remove executable
if [ -f "$HOME/.local/bin/voice-recorder" ]; then
    echo "⚙️ Removing global command"
    rm "$HOME/.local/bin/voice-recorder"
fi

echo "✅ Uninstall complete!"
echo "🔧 Note: PATH modifications in ~/.zshrc and ~/.bashrc are left intact"