#!/bin/bash

# Story Weaver Development Environment Setup Script
# This script sets up a complete development environment for Story Weaver

set -e  # Exit on any error

echo "🚀 Setting up Story Weaver Development Environment"
echo "=================================================="

# Check if we're on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    echo "This script supports macOS and Linux only."
    exit 1
fi

echo "📍 Detected OS: $OS"

# Check for required tools
echo "🔍 Checking for required tools..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    if [[ "$OS" == "macos" ]]; then
        echo "Install with: brew install python3"
    else
        echo "Install with: sudo apt-get install python3 python3-pip"
    fi
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d. -f1-2)
echo "✅ Python $PYTHON_VERSION found"

# Check pip
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed."
    echo "Install with: python3 -m ensurepip --upgrade"
    exit 1
fi
echo "✅ pip3 found"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed."
    if [[ "$OS" == "macos" ]]; then
        echo "Install with: brew install node"
    else
        echo "Install with: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
    fi
    exit 1
fi

NODE_VERSION=$(node --version)
echo "✅ Node.js $NODE_VERSION found"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed."
    echo "npm should come with Node.js. Please reinstall Node.js."
    exit 1
fi
echo "✅ npm found"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is required but not installed."
    echo "Install from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "✅ $FLUTTER_VERSION found"

# Setup backend environment
echo ""
echo "🐍 Setting up backend environment..."

cd backend

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Install Python dependencies
echo "📥 Installing Python dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit backend/.env with your actual API keys and configuration"
fi

# Setup frontend environment
echo ""
echo "📱 Setting up Flutter frontend environment..."

cd ..

# Install Flutter dependencies
echo "📥 Installing Flutter dependencies..."
flutter pub get

# Setup Android/iOS if applicable
if [[ "$OS" == "macos" ]]; then
    echo "🍎 Setting up iOS development environment..."
    if command -v pod &> /dev/null; then
        cd ios
        pod install
        cd ..
        echo "✅ iOS CocoaPods dependencies installed"
    else
        echo "⚠️  CocoaPods not found. Install with: sudo gem install cocoapods"
    fi
fi

# Setup Android if applicable
if [ -d "android" ]; then
    echo "🤖 Android project detected"
    # Check for Android SDK
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        echo "⚠️  ANDROID_HOME or ANDROID_SDK_ROOT not set"
        echo "Please set up Android SDK and add to your PATH"
    else
        echo "✅ Android SDK environment detected"
    fi
fi

# Final setup steps
echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit backend/.env with your API keys"
echo "2. Run 'flutter doctor' to check Flutter setup"
echo "3. Run 'flutter run' to start the app"
echo "4. Run 'cd backend && source venv/bin/activate && python run.py' to start the backend"
echo ""
echo "🔗 Useful commands:"
echo "- Backend: cd backend && source venv/bin/activate && python run.py"
echo "- Frontend: flutter run"
echo "- Tests: cd backend && source venv/bin/activate && pytest"
echo ""
echo "Happy coding! 🚀"