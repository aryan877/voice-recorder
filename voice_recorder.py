#!/usr/bin/env python3
"""
Global Voice-to-Text Recorder
Listens for hotkey, records audio, transcribes with Whisper, and pastes text
"""

import os
import sys
import threading
import tempfile
import wave
import time
import logging
import json
import platform
from datetime import datetime
from typing import Optional
from dotenv import load_dotenv
# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

import pyaudio
import pyperclip
from pynput.keyboard import Key, Listener
from openai import OpenAI

class VoiceRecorder:
    def __init__(self):
        logger.info("Initializing VoiceRecorder...")
        
        # Initialize usage log file
        self.log_file = "voice_recorder_usage.jsonl"
        
        # Check if Azure OpenAI credentials are provided
        azure_api_key = os.getenv('AZURE_OPENAI_API_KEY')
        azure_endpoint = os.getenv('AZURE_OPENAI_ENDPOINT')
        
        if azure_api_key and azure_endpoint:
            deployment_name = os.getenv('AZURE_OPENAI_DEPLOYMENT_NAME', 'gpt-4o-transcribe')
            logger.info(f"✅ Using Azure OpenAI API (deployment: {deployment_name})")
            self.api_provider = f"Azure OpenAI ({deployment_name})"
            self.client = OpenAI(
                api_key=azure_api_key,
                base_url=f"{azure_endpoint.rstrip('/')}/openai/deployments/{deployment_name}",
                default_query={"api-version": os.getenv('AZURE_OPENAI_API_VERSION', '2025-03-01-preview')}
            )
            # Set pricing based on deployment model
            if 'gpt-4o-mini-transcribe' in deployment_name:
                self.cost_per_minute = 0.003  # GPT-4o-mini-transcribe: $0.003/min
                logger.info("Using GPT-4o-mini-transcribe pricing: $0.003/minute")
            elif 'gpt-4o-transcribe' in deployment_name:
                self.cost_per_minute = 0.006  # GPT-4o-transcribe: $0.006/min
                logger.info("Using GPT-4o-transcribe pricing: $0.006/minute")
            else:
                self.cost_per_minute = 0.006  # Default to standard rate
                logger.info("Using default transcription pricing: $0.006/minute")
        else:
            logger.info("✅ Using regular OpenAI API")
            self.api_provider = "OpenAI"
            self.client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
            # OpenAI Whisper pricing: $0.006 per minute
            self.cost_per_minute = 0.006
            
        self.is_recording = False
        self.audio_frames = []
        self.recording_thread = None
        self.recording_start_time = None
        
        # Audio settings
        self.CHUNK = 1024
        self.FORMAT = pyaudio.paInt16
        self.CHANNELS = 1
        self.RATE = 44100
        
        # Track pressed keys for hotkey detection
        self.pressed_keys = set()
        
        logger.info(f"Audio settings: {self.CHANNELS} channel(s), {self.RATE}Hz, chunk size {self.CHUNK}")
        logger.info(f"Cost tracking: ${self.cost_per_minute}/minute via {self.api_provider}")
        logger.info("VoiceRecorder initialized successfully")
        
    def start_recording(self):
        """Start audio recording in a separate thread"""
        if self.is_recording:
            logger.warning("Already recording, ignoring start request")
            return
            
        self.recording_start_time = time.time()
        logger.info(f"🎙️  Starting recording at {datetime.now().strftime('%H:%M:%S')}")
        self.is_recording = True
        self.audio_frames = []
        
        def record():
            try:
                logger.info("Initializing PyAudio...")
                audio = pyaudio.PyAudio()
                
                logger.info("Opening audio stream...")
                stream = audio.open(
                    format=self.FORMAT,
                    channels=self.CHANNELS,
                    rate=self.RATE,
                    input=True,
                    frames_per_buffer=self.CHUNK
                )
                logger.info("Recording audio data...")
                frame_count = 0
                while self.is_recording:
                    data = stream.read(self.CHUNK)
                    self.audio_frames.append(data)
                    frame_count += 1
                    if frame_count % 100 == 0:  # Log every 100 chunks (~2.3 seconds)
                        logger.info(f"Recorded {frame_count} audio chunks ({len(self.audio_frames)} total)")
                
                logger.info(f"Recording finished. Total chunks: {len(self.audio_frames)}")
                stream.stop_stream()
                stream.close()
                audio.terminate()
                logger.info("Audio stream closed")
            except Exception as e:
                logger.error(f"Error during recording: {e}")
                self.is_recording = False
        
        self.recording_thread = threading.Thread(target=record)
        self.recording_thread.start()
        logger.info("Recording thread started")
    
    def stop_recording(self):
        """Stop recording and process audio"""
        if not self.is_recording:
            logger.warning("Not recording, ignoring stop request")
            return
            
        logger.info("⏹️  Stopping recording...")
        self.is_recording = False
        
        if self.recording_thread:
            logger.info("Waiting for recording thread to finish...")
            self.recording_thread.join()
            logger.info("Recording thread finished")
        
        if not self.audio_frames:
            logger.warning("No audio data recorded")
            return
            
        # Save audio to temporary file
        logger.info("Creating temporary audio file...")
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
            audio_file = tmp_file.name
            
        logger.info(f"Writing audio data to {audio_file}...")
        # Write audio data to file
        try:
            with wave.open(audio_file, 'wb') as wf:
                wf.setnchannels(self.CHANNELS)
                wf.setsampwidth(pyaudio.PyAudio().get_sample_size(self.FORMAT))
                wf.setframerate(self.RATE)
                wf.writeframes(b''.join(self.audio_frames))
            
            logger.info(f"Audio file created successfully. Size: {os.path.getsize(audio_file)} bytes")
        except Exception as e:
            logger.error(f"Error writing audio file: {e}")
            return
        
        # Transcribe audio
        logger.info("Starting transcription...")
        transcription = self.transcribe_audio(audio_file)
        
        # Clean up temporary file
        logger.info("Cleaning up temporary file...")
        os.unlink(audio_file)
        
        if transcription:
            logger.info(f"📝 Transcribed: {transcription}")
            self.paste_text(transcription)
            logger.info("✅ Copied to clipboard and pasted!")
        else:
            logger.warning("❌ No transcription received")
    
    def transcribe_audio(self, audio_file: str) -> Optional[str]:
        """Transcribe audio using OpenAI Whisper"""
        file_size = os.path.getsize(audio_file)
        
        # Calculate recording duration and estimated cost
        recording_duration = time.time() - self.recording_start_time if self.recording_start_time else 0
        audio_duration_minutes = recording_duration / 60
        estimated_cost = audio_duration_minutes * self.cost_per_minute
        
        logger.info(f"📊 Recording stats:")
        logger.info(f"   • Duration: {recording_duration:.2f}s ({audio_duration_minutes:.3f} minutes)")
        logger.info(f"   • File size: {file_size:,} bytes ({file_size/1024:.1f} KB)")
        logger.info(f"   • Estimated cost: ${estimated_cost:.4f}")
        logger.info(f"   • API Provider: {self.api_provider}")
        
        try:
            logger.info(f"🔗 Sending to {self.api_provider} Whisper API...")
            with open(audio_file, "rb") as file:
                api_start = time.time()
                response = self.client.audio.transcriptions.create(
                    model="whisper-1",
                    file=file,
                    response_format="text"
                )
                api_duration = time.time() - api_start
                result = response.strip()
                
                # Log usage to file
                usage_data = {
                    "timestamp": datetime.now().isoformat(),
                    "api_provider": self.api_provider,
                    "recording_duration_seconds": round(recording_duration, 2),
                    "recording_duration_minutes": round(audio_duration_minutes, 4),
                    "file_size_bytes": file_size,
                    "file_size_kb": round(file_size/1024, 1),
                    "api_response_time_seconds": round(api_duration, 2),
                    "transcription_length_chars": len(result),
                    "estimated_cost_usd": round(estimated_cost, 6),
                    "transcription_text": result[:100] + "..." if len(result) > 100 else result
                }
                
                # Append to log file
                with open(self.log_file, "a", encoding="utf-8") as log_f:
                    log_f.write(json.dumps(usage_data) + "\n")
                
                logger.info(f"✅ Transcription successful:")
                logger.info(f"   • API Response time: {api_duration:.2f}s")
                logger.info(f"   • Result length: {len(result)} characters")
                logger.info(f"   • Cost: ${estimated_cost:.4f} via {self.api_provider}")
                logger.info(f"   • Logged to: {self.log_file}")
                
                return result
                
        except Exception as e:
            logger.error(f"❌ {self.api_provider} Transcription error: {e}")
            
            # Log failed attempt
            error_data = {
                "timestamp": datetime.now().isoformat(),
                "api_provider": self.api_provider,
                "recording_duration_seconds": round(recording_duration, 2),
                "file_size_bytes": file_size,
                "error": str(e),
                "status": "failed"
            }
            
            with open(self.log_file, "a", encoding="utf-8") as log_f:
                log_f.write(json.dumps(error_data) + "\n")
                
            return None
    
    def paste_text(self, text: str):
        """Copy to clipboard and paste at cursor position"""
        logger.info("Copying text to clipboard...")
        # Copy to clipboard
        pyperclip.copy(text)
        
        logger.info("Waiting 0.2s for clipboard to be set...")
        # Small delay to ensure clipboard is set
        time.sleep(0.2)
        
        system = platform.system()
        logger.info(f"Pasting text on {system}...")
        
        try:
            if system == "Darwin":  # macOS
                # Use AppleScript for reliable Cmd+V on macOS
                import subprocess
                subprocess.run([
                    'osascript', '-e', 
                    'tell application "System Events" to keystroke "v" using command down'
                ], check=True, capture_output=True)
                logger.info("Paste command sent successfully via AppleScript")
                
            elif system == "Windows":
                # Use pynput keyboard controller for Windows
                from pynput.keyboard import Key, Controller
                keyboard = Controller()
                keyboard.press(Key.ctrl)
                keyboard.press('v')
                keyboard.release('v')
                keyboard.release(Key.ctrl)
                logger.info("Paste command sent successfully via pynput (Ctrl+V)")
                
            else:  # Linux and other Unix-like systems
                # Use pynput keyboard controller for Linux
                from pynput.keyboard import Key, Controller
                keyboard = Controller()
                keyboard.press(Key.ctrl)
                keyboard.press('v')
                keyboard.release('v')
                keyboard.release(Key.ctrl)
                logger.info("Paste command sent successfully via pynput (Ctrl+V)")
                
        except Exception as e:
            logger.error(f"Paste failed on {system}: {e}")
            logger.info("Text copied to clipboard - paste manually with Ctrl+V (or Cmd+V on macOS)")
    
    def on_key_press(self, key):
        """Handle key press events"""
        self.pressed_keys.add(key)
        
        # Check for Cmd+` combination (backtick key)
        if (hasattr(key, 'char') and key.char == '`' and Key.cmd in self.pressed_keys):
            
            logger.info("Hotkey detected: Cmd+`")
            if self.is_recording:
                logger.info("Stopping recording due to hotkey")
                self.stop_recording()
            else:
                logger.info("Starting recording due to hotkey")
                self.start_recording()
    
    def on_key_release(self, key):
        """Handle key release events"""
        try:
            self.pressed_keys.discard(key)
        except KeyError:
            pass
    
    def run(self):
        """Start the global hotkey listener"""
        logger.info("🎯 Voice Recorder starting...")
        logger.info("📌 Hotkey: Cmd+` (press to toggle recording)")
        logger.info("🚪 Press Ctrl+C to exit")
        
        # Check for API keys
        azure_key = os.getenv('AZURE_OPENAI_API_KEY')
        openai_key = os.getenv('OPENAI_API_KEY')
        
        if not azure_key and not openai_key:
            logger.error("❌ Error: Either OPENAI_API_KEY or AZURE_OPENAI_API_KEY must be set")
            sys.exit(1)
        logger.info("✅ API key found")
        
        logger.info("Starting keyboard listener...")
        with Listener(
            on_press=self.on_key_press,
            on_release=self.on_key_release
        ) as listener:
            logger.info("Keyboard listener active, waiting for hotkey...")
            listener.join()
        logger.info("Keyboard listener stopped")

def main():
    logger.info("=== Voice Recorder Application Starting ===")
    try:
        recorder = VoiceRecorder()
        recorder.run()
    except KeyboardInterrupt:
        logger.info("Application interrupted by user")
    except Exception as e:
        logger.error(f"Application error: {e}")
    finally:
        logger.info("=== Voice Recorder Application Ended ===")

if __name__ == "__main__":
    print("=== SCRIPT STARTING ===")
    print("Python executable:", sys.executable)
    print("Current working directory:", os.getcwd())
    print("Environment variables loaded")
    main()