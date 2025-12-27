#!/usr/bin/env node
/**
 * MCP Server for Browser Automation using Playwright
 * 
 * This server provides tools to:
 * - Launch and control browsers
 * - Navigate to URLs
 * - Click elements, fill forms
 * - Take screenshots
 * - Run Flutter web apps in browser
 * - Execute browser-based tests
 */

import { spawn } from 'child_process';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Read stdin for MCP protocol messages
const input = readFileSync(0, 'utf8');
const req = JSON.parse(input);
const { method, params, id } = req;

// Store active browser/page instances
const browsers = new Map();
let pageCounter = 0;

async function handle() {
  if (method === 'initialize') {
    return {
      id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {},
        },
        serverInfo: {
          name: 'browser-automation',
          version: '1.0.0',
        },
      },
    };
  }

  if (method === 'tools/list') {
    return {
      id,
      result: {
        tools: [
          {
            name: 'launch_browser',
            description: 'Launch a browser instance (Chrome, Firefox, or WebKit)',
            inputSchema: {
              type: 'object',
              properties: {
                browser: {
                  type: 'string',
                  enum: ['chrome', 'firefox', 'webkit'],
                  default: 'chrome',
                  description: 'Browser to launch',
                },
                headless: {
                  type: 'boolean',
                  default: false,
                  description: 'Run in headless mode',
                },
                url: {
                  type: 'string',
                  description: 'Initial URL to navigate to',
                },
              },
            },
          },
          {
            name: 'navigate',
            description: 'Navigate to a URL in the active browser',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID from launch_browser',
                },
                url: {
                  type: 'string',
                  description: 'URL to navigate to',
                },
              },
              required: ['pageId', 'url'],
            },
          },
          {
            name: 'click_element',
            description: 'Click an element on the page',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID',
                },
                selector: {
                  type: 'string',
                  description: 'CSS selector or text to click',
                },
                waitForSelector: {
                  type: 'boolean',
                  default: true,
                  description: 'Wait for selector to be visible',
                },
              },
              required: ['pageId', 'selector'],
            },
          },
          {
            name: 'fill_input',
            description: 'Fill an input field',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID',
                },
                selector: {
                  type: 'string',
                  description: 'CSS selector for input field',
                },
                value: {
                  type: 'string',
                  description: 'Value to fill',
                },
              },
              required: ['pageId', 'selector', 'value'],
            },
          },
          {
            name: 'take_screenshot',
            description: 'Take a screenshot of the current page',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID',
                },
                path: {
                  type: 'string',
                  description: 'Path to save screenshot',
                  default: 'screenshot.png',
                },
                fullPage: {
                  type: 'boolean',
                  default: false,
                  description: 'Capture full page',
                },
              },
              required: ['pageId'],
            },
          },
          {
            name: 'get_page_text',
            description: 'Get all text content from the page',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID',
                },
                selector: {
                  type: 'string',
                  description: 'Optional CSS selector to get text from specific element',
                },
              },
              required: ['pageId'],
            },
          },
          {
            name: 'wait_for_element',
            description: 'Wait for an element to appear on the page',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID',
                },
                selector: {
                  type: 'string',
                  description: 'CSS selector to wait for',
                },
                timeout: {
                  type: 'number',
                  default: 30000,
                  description: 'Timeout in milliseconds',
                },
              },
              required: ['pageId', 'selector'],
            },
          },
          {
            name: 'run_flutter_app',
            description: 'Start Flutter app in browser and return page ID',
            inputSchema: {
              type: 'object',
              properties: {
                browser: {
                  type: 'string',
                  enum: ['chrome', 'firefox', 'webkit'],
                  default: 'chrome',
                },
                headless: {
                  type: 'boolean',
                  default: false,
                },
                port: {
                  type: 'number',
                  default: 8080,
                  description: 'Port Flutter web app runs on',
                },
              },
            },
          },
          {
            name: 'close_browser',
            description: 'Close a browser instance',
            inputSchema: {
              type: 'object',
              properties: {
                pageId: {
                  type: 'string',
                  description: 'Page ID to close',
                },
              },
              required: ['pageId'],
            },
          },
        ],
      },
    };
  }

  if (method === 'tools/call') {
    const { name, arguments: args } = params;

    try {
      let result;

      switch (name) {
        case 'launch_browser':
        case 'run_flutter_app': {
          // Use Playwright via Node.js script
          const pageId = `page_${++pageCounter}`;
          const scriptPath = join(__dirname, 'mcp-playwright-helper.js');
          
          const child = spawn('node', [
            scriptPath,
            name,
            JSON.stringify(args || {}),
            pageId,
          ], {
            stdio: ['pipe', 'pipe', 'pipe'],
          });

          let output = '';
          let error = '';

          child.stdout.on('data', (data) => {
            output += data.toString();
          });

          child.stderr.on('data', (data) => {
            error += data.toString();
          });

          await new Promise((resolve, reject) => {
            child.on('close', (code) => {
              if (code === 0) {
                try {
                  const data = JSON.parse(output);
                  browsers.set(pageId, data);
                  resolve(data);
                } catch (e) {
                  reject(new Error(`Failed to parse output: ${output}`));
                }
              } else {
                reject(new Error(`Process failed: ${error || output}`));
              }
            });
          });

          result = {
            pageId,
            url: args?.url || 'about:blank',
            message: name === 'run_flutter_app' 
              ? `Flutter app starting on http://localhost:${args?.port || 8080}. Please run: flutter run -d ${args?.browser || 'chrome'}`
              : 'Browser launched successfully',
          };
          break;
        }

        case 'navigate':
        case 'click_element':
        case 'fill_input':
        case 'take_screenshot':
        case 'get_page_text':
        case 'wait_for_element': {
          const pageId = args.pageId;
          const pageData = browsers.get(pageId);
          
          if (!pageData) {
            throw new Error(`Page ${pageId} not found`);
          }

          const scriptPath = join(__dirname, 'mcp-playwright-helper.js');
          const child = spawn('node', [
            scriptPath,
            name,
            JSON.stringify(args),
            pageId,
          ]);

          let output = '';
          let error = '';

          child.stdout.on('data', (data) => {
            output += data.toString();
          });

          child.stderr.on('data', (data) => {
            error += data.toString();
          });

          await new Promise((resolve, reject) => {
            child.on('close', (code) => {
              if (code === 0) {
                try {
                  result = JSON.parse(output);
                  resolve(result);
                } catch (e) {
                  result = { success: true, message: output };
                  resolve(result);
                }
              } else {
                reject(new Error(`Process failed: ${error || output}`));
              }
            });
          });
          break;
        }

        case 'close_browser': {
          const pageId = args.pageId;
          browsers.delete(pageId);
          result = { success: true, message: `Browser ${pageId} closed` };
          break;
        }

        default:
          throw new Error(`Unknown tool: ${name}`);
      }

      return {
        id,
        result: {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        },
      };
    } catch (error) {
      return {
        id,
        error: {
          code: -1,
          message: error.message,
        },
      };
    }
  }

  return {
    id,
    result: {},
  };
}

const response = await handle();
console.log(JSON.stringify(response));


