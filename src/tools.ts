/**
 * Tool definitions and handlers for Scenic MCP
 *
 * This module contains ONLY:
 * - Tool schemas (what tools are available)
 * - Tool handlers (what each tool does)
 *
 * All connection/process management is in connection.ts
 * All server setup is in index.ts
 */

import { getConnectionContext } from './connection.js';

// Get connection context for making requests to Elixir
const conn = getConnectionContext();

// ========================================================================
// Tool Definitions
// ========================================================================

export function getToolDefinitions() {
  return [
    {
      name: 'connect_scenic',
      description: 'CONNECTION SETUP: Establish the connection to the ScenicMCP GenServer running inside our Scenic app. Use this first before other interaction tools.',
      inputSchema: {
        type: 'object',
        properties: {
          port: {
            type: 'number',
            description: 'TCP port (default: 9999)',
            default: 9999,
          },
        },
      },
    },
    {
      name: 'get_scenic_status',
      description: 'CONNECTION STATUS: Check if we are connected to a Scenic app and fetch details.',
      inputSchema: {
        type: 'object',
        properties: {},
        required: [],
      },
    },
    {
      name: 'send_keys',
      description: 'KEYBOARD INPUT: Send text input or special keystrokes to the Scenic application. Use for typing text, navigation shortcuts, testing keyboard interactions. Supports text, special keys (enter, escape, tab), and modifier combinations (ctrl+c, cmd+s).',
      inputSchema: {
        type: 'object',
        properties: {
          text: {
            type: 'string',
            description: 'Text to type (each character will be sent as individual key presses)',
          },
          key: {
            type: 'string',
            description: 'Special key name (e.g., enter, escape, tab, backspace, delete, up, down, left, right, home, end, page_up, page_down, f1-f12)',
          },
          modifiers: {
            type: 'array',
            items: {
              type: 'string',
              enum: ['ctrl', 'shift', 'alt', 'cmd', 'meta'],
            },
            description: 'Modifier keys to hold while pressing the key',
          },
        },
      },
    },
    {
      name: 'send_mouse_move',
      description: 'CURSOR MOVEMENT: Move the mouse cursor to specific coordinates. Useful for hover effects, precise positioning before clicking, and testing mouse-over interactions.',
      inputSchema: {
        type: 'object',
        properties: {
          x: {
            type: 'number',
            description: 'X coordinate',
          },
          y: {
            type: 'number',
            description: 'Y coordinate',
          },
        },
        required: ['x', 'y'],
      },
    },
    {
      name: 'send_mouse_click',
      description: 'MOUSE INTERACTION: Click at specific screen coordinates to interact with buttons, links, and UI elements. Use with inspect_viewport to find clickable elements and their positions. Essential for testing UI interactions.',
      inputSchema: {
        type: 'object',
        properties: {
          x: {
            type: 'number',
            description: 'X coordinate',
          },
          y: {
            type: 'number',
            description: 'Y coordinate',
          },
          button: {
            type: 'string',
            enum: ['left', 'right', 'middle'],
            description: 'Mouse button to click (default: left)',
            default: 'left',
          },
        },
        required: ['x', 'y'],
      },
    },
    {
      name: 'inspect_viewport',
      description: 'UI ANALYSIS: Get a detailed text-based description of what\'s currently displayed in the Scenic application. Perfect for understanding UI structure, finding clickable elements, and programmatic interface analysis. Use when you need to understand what\'s on screen without taking a screenshot.',
      inputSchema: {
        type: 'object',
        properties: {},
      },
    },
    {
      name: 'take_screenshot',
      description: 'VISUAL DOCUMENTATION: Capture screenshots of the Scenic application for development progress tracking, debugging UI issues, creating before/after comparisons, and documenting visual changes. Essential for visual development workflows. Use when someone wants to "see how the app looks" or "capture current state".',
      inputSchema: {
        type: 'object',
        properties: {
          format: {
            type: 'string',
            enum: ['path', 'base64'],
            description: 'Output format - return file path or base64-encoded image data (default: path)',
            default: 'path',
          },
          filename: {
            type: 'string',
            description: 'Optional filename (will be auto-generated if not provided)',
          },
        },
      },
    },
  ];
}

// ========================================================================
// Tool Handler Router
// ========================================================================

export async function handleToolCall(name: string, args: any) {
  switch (name) {
    case 'connect_scenic':
      return await handleConnectScenic(args);
    case 'get_scenic_status':
      return await handleGetScenicStatus(args);
    case 'send_keys':
      return await handleSendKeys(args);
    case 'send_mouse_move':
      return await handleSendMouseMove(args);
    case 'send_mouse_click':
      return await handleSendMouseClick(args);
    case 'inspect_viewport':
      return await handleInspectViewport(args);
    case 'take_screenshot':
      return await handleTakeScreenshot(args);
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// ========================================================================
// Tool Handler Implementations
// ========================================================================

async function handleConnectScenic(args: any) {
  try {
    const { port = 9999 } = args;

    conn.setCurrentPort(port);
    const isRunning = await conn.checkTCPServer(port);

    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: `No Scenic TCP server found on port ${port}.\n\nStatus: Waiting for connection\n\nTo use Scenic MCP, your Scenic application needs to include the ScenicMcp.Server module and start it on the specified port. The MCP server will continue monitoring for the connection.`,
          },
        ],
        isError: false,
      };
    }

    const response = await conn.sendToElixir('hello');
    const data = JSON.parse(response);

    return {
      content: [
        {
          type: 'text',
          text: `Successfully connected to Scenic application!\n\nServer info:\n${JSON.stringify(data, null, 2)}`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error connecting to Scenic application: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleGetScenicStatus(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();

    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: `Scenic MCP Status:\n- Connection: Waiting for Scenic app\n- TCP Port: ${conn.getCurrentPort()}\n\nThe MCP server is running but no Scenic application is connected. Start your Scenic app and the connection will be automatically detected.`,
          },
        ],
      };
    }

    const response = await conn.sendToElixir({ action: 'status' });
    const data = JSON.parse(response);

    return {
      content: [
        {
          type: 'text',
          text: `Scenic MCP Status:\n- Connection: Active\n- TCP Port: ${conn.getCurrentPort()}\n\nServer details:\n${JSON.stringify(data, null, 2)}`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Status: Connected but error getting details\nError: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
    };
  }
}

async function handleSendKeys(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot send keys: No Scenic application connected.\n\nUse connect_scenic first or start your Scenic application. The MCP server will automatically detect when the app becomes available.',
          },
        ],
        isError: false,
      };
    }

    const { text, key, modifiers } = args;

    if (!text && !key) {
      return {
        content: [
          {
            type: 'text',
            text: 'Error: Must provide either "text" or "key" parameter',
          },
        ],
        isError: true,
      };
    }

    const command = {
      action: 'send_keys',
      text,
      key,
      modifiers: modifiers || [],
    };

    const response = await conn.sendToElixir(command);
    const data = JSON.parse(response);

    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error sending keys: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: `Keys sent successfully!\n${JSON.stringify(data, null, 2)}`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error sending keys: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleSendMouseMove(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot send mouse move: No Scenic application connected.\n\nStart your Scenic application first.',
          },
        ],
        isError: false,
      };
    }

    const { x, y } = args;

    const command = {
      action: 'send_mouse_move',
      x,
      y,
    };

    const response = await conn.sendToElixir(command);
    const data = JSON.parse(response);

    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error moving mouse: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: `Mouse moved to (${x}, ${y})`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error moving mouse: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleSendMouseClick(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot send mouse click: No Scenic application connected.\n\nStart your Scenic application first.',
          },
        ],
        isError: false,
      };
    }

    const { x, y, button = 'left' } = args;

    const command = {
      action: 'send_mouse_click',
      x,
      y,
      button,
    };

    const response = await conn.sendToElixir(command);
    const data = JSON.parse(response);

    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error clicking mouse: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: `Mouse clicked at (${x}, ${y}) with ${button} button`,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error clicking mouse: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleInspectViewport(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot inspect viewport: No Scenic application connected.\n\nStart your Scenic application first to inspect its interface.',
          },
        ],
        isError: false,
      };
    }

    const command = {
      action: 'inspect_viewport',
    };

    const response = await conn.sendToElixir(command);
    const data = JSON.parse(response);

    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error inspecting viewport: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    let inspectionText = `Viewport Inspection Results\n${'='.repeat(50)}\n\n`;

    if (data.visual_description) {
      inspectionText += `Visual Description: ${data.visual_description}\n`;
      inspectionText += `Script Count: ${data.script_count}\n\n`;
    }

    if (data.semantic_elements && data.semantic_elements.count > 0) {
      inspectionText += `Semantic DOM Summary\n${'-'.repeat(30)}\n`;
      inspectionText += `Total Elements: ${data.semantic_elements.count}\n`;
      inspectionText += `Clickable Elements: ${data.semantic_elements.clickable_count}\n`;

      if (data.semantic_elements.summary) {
        inspectionText += `Summary: ${data.semantic_elements.summary}\n`;
      }

      if (data.semantic_elements.by_type && Object.keys(data.semantic_elements.by_type).length > 0) {
        inspectionText += `\nElements by Type:\n`;
        for (const [type, count] of Object.entries(data.semantic_elements.by_type)) {
          inspectionText += `  - ${type}: ${count}\n`;
        }
      }

      const clickableElements = data.semantic_elements.elements?.filter((e: any) => e.clickable) || [];
      if (clickableElements.length > 0) {
        inspectionText += `\nClickable Elements:\n`;
        clickableElements.forEach((elem: any) => {
          const posStr = elem.position ? ` at (${elem.position.x}, ${elem.position.y})` : '';
          inspectionText += `  - ${elem.label || elem.type}${posStr}\n`;
          if (elem.description) {
            inspectionText += `    ${elem.description}\n`;
          }
        });
      }
    } else {
      inspectionText += `\nNo semantic DOM information available.\n`;
      inspectionText += `(Components need semantic annotations to appear here)\n`;
    }

    return {
      content: [
        {
          type: 'text',
          text: inspectionText,
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error inspecting viewport: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleTakeScreenshot(args: any) {
  try {
    const isRunning = await conn.checkTCPServer();
    if (!isRunning) {
      return {
        content: [
          {
            type: 'text',
            text: 'Cannot take screenshot: Scenic TCP server is not running.',
          },
        ],
        isError: true,
      };
    }

    const { format = 'path', filename } = args;

    const command = {
      action: 'take_screenshot',
      format,
      filename,
    };

    const response = await conn.sendToElixir(command);
    const data = JSON.parse(response);

    if (data.error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error taking screenshot: ${data.error}`,
          },
        ],
        isError: true,
      };
    }

    if (format === 'base64' && data.data) {
      return {
        content: [
          {
            type: 'text',
            text: `Screenshot captured successfully!\nFormat: base64\nSize: ${data.size} bytes\nPath: ${data.path}`,
          },
          {
            type: 'image',
            data: data.data,
            mimeType: 'image/png',
          },
        ],
      };
    } else {
      return {
        content: [
          {
            type: 'text',
            text: `Screenshot saved to: ${data.path}`,
          },
        ],
      };
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error taking screenshot: ${error instanceof Error ? error.message : 'Unknown error'}`,
        },
      ],
      isError: true,
    };
  }
}
