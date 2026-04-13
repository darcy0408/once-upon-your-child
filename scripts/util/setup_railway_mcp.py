#!/usr/bin/env python3
"""
Railway MCP Setup and Testing Helper
Sets up Railway MCP server for automated deployment testing
"""
import os
import json
import subprocess
import sys
from pathlib import Path

def setup_railway_mcp():
    """Set up Railway MCP server for testing"""

    print("🚂 Setting up Railway MCP for automated testing...")
    print("=" * 60)

    # Check if Railway CLI is installed
    try:
        result = subprocess.run(["railway", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Railway CLI found")
        else:
            print("❌ Railway CLI not found")
            print("   Install with: npm install -g @railway/cli")
            return False
    except FileNotFoundError:
        print("❌ Railway CLI not found")
        print("   Install with: npm install -g @railway/cli")
        return False

    # Check for Railway token
    railway_token = os.getenv('RAILWAY_TOKEN')
    if not railway_token:
        print("❌ RAILWAY_TOKEN environment variable not set")
        print("\nTo get your Railway token:")
        print("1. Go to Railway dashboard")
        print("2. Settings → Tokens")
        print("3. Create a new token")
        print("4. Set environment variable: export RAILWAY_TOKEN=your_token_here")
        return False

    print("✅ RAILWAY_TOKEN found")

    # Check if Railway MCP server exists
    mcp_file = Path("railway-mcp.js")
    if not mcp_file.exists():
        print("❌ railway-mcp.js not found")
        return False

    print("✅ Railway MCP server found")

    # Test Railway connection
    try:
        print("\n🔗 Testing Railway connection...")
        result = subprocess.run(["railway", "whoami"], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ Railway connection successful")
            return True
        else:
            print("❌ Railway connection failed")
            print(f"   Error: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print("❌ Railway connection timeout")
        return False
    except Exception as e:
        print(f"❌ Railway connection error: {e}")
        return False

def test_railway_deployment_with_mcp(backend_url=None):
    """Test Railway deployment using MCP server"""

    if not setup_railway_mcp():
        print("\n❌ Cannot set up Railway MCP. Using manual testing instead.")
        print("Run: python test_railway_deployment.py")
        return False

    print("\n🧪 Testing Railway deployment with MCP...")

    # Get backend URL if not provided
    if not backend_url:
        try:
            # Try to get Railway services
            result = subprocess.run([
                "node", "railway-mcp.js"
            ], input=json.dumps({
                "method": "call",
                "params": {"name": "railway.services"},
                "id": 1
            }), capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                try:
                    response = json.loads(result.stdout)
                    if "result" in response:
                        # Parse services to find backend URL
                        print("✅ Found Railway services")
                        # For now, ask user for URL since parsing is complex
                        backend_url = input("Enter your Railway backend URL: ").strip()
                    else:
                        backend_url = input("Enter your Railway backend URL: ").strip()
                except:
                    backend_url = input("Enter your Railway backend URL: ").strip()
            else:
                backend_url = input("Enter your Railway backend URL: ").strip()
        except:
            backend_url = input("Enter your Railway backend URL: ").strip()

    if backend_url:
        # Run the existing test script
        print(f"\n🚀 Testing deployment at: {backend_url}")
        os.system(f"python test_railway_deployment.py {backend_url}")
        return True
    else:
        print("❌ No backend URL provided")
        return False

def create_railway_mcp_config():
    """Create MCP configuration for Railway testing"""

    config = {
        "mcpServers": {
            "railway": {
                "command": "node",
                "args": ["railway-mcp.js"],
                "env": {
                    "RAILWAY_TOKEN": "${RAILWAY_TOKEN}"
                }
            }
        }
    }

    with open("mcp-config.json", "w") as f:
        json.dump(config, f, indent=2)

    print("📄 Created mcp-config.json for Railway MCP server")
    print("   To use: Set RAILWAY_TOKEN environment variable")

def main():
    """Main setup function"""

    if len(sys.argv) > 1 and sys.argv[1] == "--config":
        create_railway_mcp_config()
        return

    print("🚂 Railway MCP Setup for Story Weaver App")
    print("=" * 60)

    # Check if user wants to test deployment
    if len(sys.argv) > 1 and sys.argv[1].startswith("http"):
        backend_url = sys.argv[1]
        test_railway_deployment_with_mcp(backend_url)
    else:
        # Setup MCP
        if setup_railway_mcp():
            print("\n✅ Railway MCP setup complete!")
            print("\nAvailable commands:")
            print("• python setup_railway_mcp.py <backend-url>  # Test deployment")
            print("• python setup_railway_mcp.py --config        # Create MCP config")
            print("\nTo test your Railway deployment:")
            print("python setup_railway_mcp.py https://your-backend-url.up.railway.app")
        else:
            print("\n❌ Railway MCP setup failed")
            print("Falling back to manual testing...")
            print("Run: python test_railway_deployment.py")

if __name__ == "__main__":
    main()