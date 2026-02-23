import pytest
from playwright.sync_api import sync_playwright
import time

def run_test(browser_type, device_config=None, name="test"):
    with sync_playwright() as p:
        if browser_type == "chromium":
            browser = p.chromium.launch()
        elif browser_type == "firefox":
            browser = p.firefox.launch()
        elif browser_type == "webkit":
            browser = p.webkit.launch()
        else:
            print(f"Unknown browser type: {browser_type}")
            return

        if device_config:
            context = browser.new_context(**device_config)
        else:
            context = browser.new_context()

        page = context.new_page()
        print(f"Testing {name}...")
        
        try:
            page.goto("http://localhost:8080", wait_until="networkidle", timeout=90000)
            
            # Try a few different selectors that Flutter might use
            selectors = ["flt-glass-pane", "flutter-view", "flt-scene-host", "body"]
            found = False
            for selector in selectors:
                try:
                    page.wait_for_selector(selector, timeout=10000)
                    print(f"   Found selector: {selector}")
                    found = True
                    break
                except:
                    continue
            
            if not found:
                print(f"   ⚠️ No specific Flutter selector found, continuing anyway...")

            time.sleep(10) # Give it plenty of time to render the first frame
            
            page.screenshot(path=f"screenshot_{name}.png")
            print(f"✅ {name} loaded successfully.")
            
            # Basic interaction check - click somewhere
            # page.mouse.click(100, 100)
            
        except Exception as e:
            print(f"❌ {name} failed: {str(e)}")
            page.screenshot(path=f"error_{name}.png")
        
        browser.close()

if __name__ == "__main__":
    import requests
    
    print("Checking if web server is up on http://localhost:8080...")
    try:
        requests.get("http://localhost:8080", timeout=5)
        print("✅ Server is up!")
    except Exception as e:
        print(f"❌ Server is NOT up: {e}")
        print("Please run: Start-Process python -ArgumentList '-m http.server 8080 --directory build/web' -WindowStyle Hidden")
        exit(1)
    
    # Chrome Desktop
    run_test("chromium", name="chrome_desktop")
    
    # Firefox Desktop
    run_test("firefox", name="firefox_desktop")
    
    # Safari Desktop (Webkit)
    # run_test("webkit", name="safari_desktop")
    
    # Mobile Chrome (Pixel 5)
    run_test("chromium", 
             device_config={"viewport": {"width": 393, "height": 851}, "is_mobile": True}, 
             name="mobile_chrome")
    
    # Mobile Safari (iPhone 12)
    # run_test("webkit", 
    #          device_config={"viewport": {"width": 390, "height": 844}, "is_mobile": True}, 
    #          name="mobile_safari")
