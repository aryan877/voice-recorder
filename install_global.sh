#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Installing Voice Recorder globally..."

# Resolve Python 3
if command -v python3 >/dev/null 2>&1; then
  PY3=python3
elif command -v python >/dev/null 2>&1 && [[ "$(python -c 'import sys;print(sys.version_info[0])' 2>/dev/null || echo 0)" == "3" ]]; then
  PY3=python
else
  echo "❌ Python 3 not found. Please install Python 3.7+ first." >&2
  exit 1
fi

# Create global directory
GLOBAL_DIR="$HOME/.voice-recorder"
mkdir -p "$GLOBAL_DIR"

# Copy files to global location
echo "📁 Copying files to $GLOBAL_DIR"
cp -f voice_recorder.py "$GLOBAL_DIR/"
cp -f requirements.txt "$GLOBAL_DIR/" || true
if [[ -f .env ]]; then cp -f .env "$GLOBAL_DIR/"; else echo "   ⚠️  .env not found, skipping"; fi

# Create virtual environment in global location
echo "🐍 Creating global Python environment..."
cd "$GLOBAL_DIR"
$PY3 -m venv venv
source venv/bin/activate

# Install requirements
echo "📦 Installing requirements globally..."
$PY3 -m pip install --upgrade pip
if [[ -f requirements.txt ]]; then
  $PY3 -m pip install -r requirements.txt
else
  echo "   ⚠️  requirements.txt not found, skipping package installation"
fi

# Ensure local bin exists
mkdir -p "$HOME/.local/bin"

# Create executable script
echo "⚙️ Creating global command..."
cat > "$HOME/.local/bin/voice-recorder" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/.voice-recorder"
source venv/bin/activate
python voice_recorder.py "$@"
EOF

# Make it executable
chmod +x "$HOME/.local/bin/voice-recorder"

# Add to PATH if not already there and append to appropriate rc files
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "🔧 Adding ~/.local/bin to PATH (shell rc)"
  LINE='export PATH="$HOME/.local/bin:$PATH"'
  # Detect default shell
  SHELL_NAME="${SHELL##*/}"
  case "$SHELL_NAME" in
    zsh)
      grep -qxF "$LINE" "$HOME/.zshrc" 2>/dev/null || echo "$LINE" >> "$HOME/.zshrc"
      ;;
    bash)
      grep -qxF "$LINE" "$HOME/.bashrc" 2>/dev/null || echo "$LINE" >> "$HOME/.bashrc"
      ;;
    fish)
      mkdir -p "$HOME/.config/fish"
      grep -qxF "set -gx PATH $HOME/.local/bin $PATH" "$HOME/.config/fish/config.fish" 2>/dev/null || echo "set -gx PATH $HOME/.local/bin $PATH" >> "$HOME/.config/fish/config.fish"
      ;;
    *)
      # Fallback to both bashrc and zshrc if we can't detect
      grep -qxF "$LINE" "$HOME/.zshrc" 2>/dev/null || echo "$LINE" >> "$HOME/.zshrc"
      grep -qxF "$LINE" "$HOME/.bashrc" 2>/dev/null || echo "$LINE" >> "$HOME/.bashrc"
      ;;
  esac
fi

echo "✅ Global installation complete!"
echo
echo "🎯 Usage from any directory:"
echo "  voice-recorder"
echo
echo "🔧 To update your .env globally:"
echo "  nano ~/.voice-recorder/.env"
echo
echo "📊 Usage logs will be saved to:"
echo "  ~/.voice-recorder/voice_recorder_usage.jsonl"
echo
echo "🔄 Restart your terminal or run: 'exec \"$SHELL\"' to reload PATH"
