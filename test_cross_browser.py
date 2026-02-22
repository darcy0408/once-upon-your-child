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
            page.goto("http://localhost:8080", timeout=60000)
            # Wait for some element that indicates the app loaded
            # Flutter apps often have a loading indicator or just the canvas
            page.wait_for_selector("flt-glass-pane", timeout=30000)
            
            time.sleep(5) # Give it a moment to render
            
            page.screenshot(path=f"screenshot_{name}.png")
            print(f"✅ {name} loaded successfully.")
            
            # Basic interaction check - click somewhere
            # page.mouse.click(100, 100)
            
        except Exception as e:
            print(f"❌ {name} failed: {str(e)}")
            page.screenshot(path=f"error_{name}.png")
        
        browser.close()

if __name__ == "__main__":
    # Wait for server to be ready
    print("Waiting for servers to be ready...")
    # Add logic here to wait for port 8080 if needed
    
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
