#!/usr/bin/env node
/**
 * Playwright helper script for MCP browser automation
 * This script handles actual Playwright operations
 */

import { chromium, firefox, webkit } from 'playwright';
import { writeFileSync } from 'fs';

const [command, argsJson, pageId] = process.argv.slice(2);
const args = JSON.parse(argsJson || '{}');

// Store browser/page instances globally (in a real implementation, use a proper store)
global.browserInstances = global.browserInstances || new Map();
global.pageInstances = global.pageInstances || new Map();

async function main() {
  try {
    let result;

    switch (command) {
      case 'launch_browser':
      case 'run_flutter_app': {
        const browserType = args.browser === 'firefox' ? firefox : 
                           args.browser === 'webkit' ? webkit : chromium;
        
        const browser = await browserType.launch({
          headless: args.headless !== false,
        });

        const context = await browser.newContext();
        const page = await context.newPage();

        global.browserInstances.set(pageId, browser);
        global.pageInstances.set(pageId, page);

        if (args.url) {
          await page.goto(args.url);
        } else if (command === 'run_flutter_app') {
          const port = args.port || 8080;
          await page.goto(`http://localhost:${port}`);
        }

        result = {
          success: true,
          pageId,
          url: page.url(),
        };
        break;
      }

      case 'navigate': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        await page.goto(args.url);
        await page.waitForLoadState('networkidle');

        result = {
          success: true,
          url: page.url(),
        };
        break;
      }

      case 'click_element': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        if (args.waitForSelector !== false) {
          await page.waitForSelector(args.selector, { timeout: 30000 });
        }

        // Try clicking by text if selector doesn't work
        try {
          await page.click(args.selector);
        } catch (e) {
          await page.click(`text=${args.selector}`);
        }

        await page.waitForTimeout(500); // Wait for any animations

        result = {
          success: true,
          message: `Clicked element: ${args.selector}`,
        };
        break;
      }

      case 'fill_input': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        await page.fill(args.selector, args.value);
        await page.waitForTimeout(300);

        result = {
          success: true,
          message: `Filled ${args.selector} with ${args.value}`,
        };
        break;
      }

      case 'take_screenshot': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        const path = args.path || `screenshot_${Date.now()}.png`;
        await page.screenshot({
          path,
          fullPage: args.fullPage || false,
        });

        result = {
          success: true,
          path,
          message: `Screenshot saved to ${path}`,
        };
        break;
      }

      case 'get_page_text': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        let text;
        if (args.selector) {
          const element = await page.$(args.selector);
          text = element ? await element.textContent() : '';
        } else {
          text = await page.textContent('body');
        }

        result = {
          success: true,
          text: text || '',
        };
        break;
      }

      case 'wait_for_element': {
        const page = global.pageInstances.get(args.pageId);
        if (!page) throw new Error(`Page ${args.pageId} not found`);

        await page.waitForSelector(args.selector, {
          timeout: args.timeout || 30000,
        });

        result = {
          success: true,
          message: `Element ${args.selector} found`,
        };
        break;
      }

      default:
        throw new Error(`Unknown command: ${command}`);
    }

    console.log(JSON.stringify(result));
  } catch (error) {
    console.error(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack,
    }));
    process.exit(1);
  }
}

main();


