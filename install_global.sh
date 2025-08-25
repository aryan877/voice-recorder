#!/bin/bash

echo "🚀 Installing Voice Recorder globally..."

# Create global directory
GLOBAL_DIR="$HOME/.voice-recorder"
mkdir -p "$GLOBAL_DIR"

# Copy files to global location
echo "📁 Copying files to $GLOBAL_DIR"
cp voice_recorder.py "$GLOBAL_DIR/"
cp requirements.txt "$GLOBAL_DIR/"
cp .env "$GLOBAL_DIR/"

# Create virtual environment in global location
echo "🐍 Creating global Python environment..."
cd "$GLOBAL_DIR"
python3 -m venv venv
source venv/bin/activate

# Install requirements
echo "📦 Installing requirements globally..."
pip install --upgrade pip
pip install -r requirements.txt

# Create executable script
echo "⚙️ Creating global command..."
cat > "$HOME/.local/bin/voice-recorder" << 'EOF'
#!/bin/bash
cd "$HOME/.voice-recorder"
source venv/bin/activate
python voice_recorder.py "$@"
EOF

# Make it executable
chmod +x "$HOME/.local/bin/voice-recorder"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "🔧 Adding to PATH..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo "✅ Global installation complete!"
echo ""
echo "🎯 Usage from any directory:"
echo "  voice-recorder"
echo ""
echo "🔧 To update your .env globally:"
echo "  nano ~/.voice-recorder/.env"
echo ""
echo "📊 Usage logs will be saved to:"
echo "  ~/.voice-recorder/voice_recorder_usage.jsonl"
echo ""
echo "🔄 Restart your terminal or run: source ~/.zshrc"