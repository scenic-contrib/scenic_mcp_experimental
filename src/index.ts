#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import * as net from 'net';

// Generic MCP server for Scenic applications
const server = new Server(
  {
    name: 'scenic-mcp',
    version: '0.2.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper function to check if TCP server is available
async function checkTCPServer(port: number = 9999): Promise<boolean> {
  return new Promise((resolve) => {
    const client = new net.Socket();
    const timeout = setTimeout(() => {
      client.destroy();
      resolve(false);
    }, 1000);

    client.connect(port, 'localhost', () => {
      clearTimeout(timeout);
      client.destroy();
      resolve(true);
    });

    client.on('error', () => {
      clearTimeout(timeout);
      resolve(false);
    });
  });
}

// Helper function to send commands to Elixir TCP server with retry logic
async function sendToElixir(command: any, retries = 3): Promise<string> {
  for (let i = 0; i < retries; i++) {
    try {
      return await attemptSendToElixir(command);
    } catch (error) {
      if (i === retries - 1) throw error;
      // Wait a bit before retrying
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
  throw new Error('Failed to send command after retries');
}

async function attemptSendToElixir(command: any): Promise<string> {
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let responseData = '';
    
    const timeout = setTimeout(() => {
      client.destroy();
      reject(new Error('Connection timeout'));
    }, 5000);
    
    client.connect(9999, 'localhost', () => {
      console.error('[Scenic MCP] Connected to TCP server');
      const message = typeof command === 'string' ? command : JSON.stringify(command);
      client.write(message + '\n');
    });
    
    client.on('data', (data) => {
      responseData += data.toString();
      if (responseData.includes('\n')) {
        clearTimeout(timeout);
        client.destroy();
        resolve(responseData.trim());
      }
    });
    
    client.on('error', (err) => {
      clearTimeout(timeout);
      reject(err);
    });
    
    client.on('close', () => {
      clearTimeout(timeout);
    });
  });
}

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'connect_scenic',
        description: 'Test connection to a Scenic application via TCP server',
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
        description: 'Check the status of the Scenic TCP connection',
        inputSchema: {
          type: 'object',
          properties: {},
          required: [],
        },
      },
      {
        name: 'send_keys',
        description: 'Send keyboard input to the connected Scenic application',
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
        description: 'Move mouse cursor to specific coordinates',
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
        description: 'Click mouse at specific coordinates',
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
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name } = request.params;

  switch (name) {
    case 'connect_scenic': {
      try {
        const { port = 9999 } = request.params.arguments as any;
        const isRunning = await checkTCPServer(port);
        
        if (!isRunning) {
          return {
            content: [
              {
                type: 'text',
                text: `No Scenic TCP server found on port ${port}.\n\nTo use Scenic MCP, your Scenic application needs to include the ScenicMcp.Server module and start it on the specified port.`,
              },
            ],
            isError: true,
          };
        }

        // Try to get info from the server
        const response = await sendToElixir('hello');
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

    case 'get_scenic_status': {
      try {
        const isRunning = await checkTCPServer();
        
        if (!isRunning) {
          return {
            content: [
              {
                type: 'text',
                text: 'Scenic TCP server is not running.\n\nStatus: Disconnected',
              },
            ],
          };
        }

        // Try to get detailed status
        const response = await sendToElixir({ action: 'status' });
        const data = JSON.parse(response);
        
        return {
          content: [
            {
              type: 'text',
              text: `Scenic MCP Status:\n- Connection: Active\n- TCP Port: 9999\n\nServer details:\n${JSON.stringify(data, null, 2)}`,
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

    case 'send_keys': {
      try {
        const isRunning = await checkTCPServer();
        if (!isRunning) {
          return {
            content: [
              {
                type: 'text',
                text: 'Cannot send keys: Scenic TCP server is not running.',
              },
            ],
            isError: true,
          };
        }

        const { text, key, modifiers } = request.params.arguments as any;
        
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
        
        const response = await sendToElixir(command);
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

    case 'send_mouse_move': {
      try {
        const isRunning = await checkTCPServer();
        if (!isRunning) {
          return {
            content: [
              {
                type: 'text',
                text: 'Cannot send mouse move: Scenic TCP server is not running.',
              },
            ],
            isError: true,
          };
        }

        const { x, y } = request.params.arguments as any;
        
        const command = {
          action: 'send_mouse_move',
          x,
          y,
        };
        
        const response = await sendToElixir(command);
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

    case 'send_mouse_click': {
      try {
        const isRunning = await checkTCPServer();
        if (!isRunning) {
          return {
            content: [
              {
                type: 'text',
                text: 'Cannot send mouse click: Scenic TCP server is not running.',
              },
            ],
            isError: true,
          };
        }

        const { x, y, button = 'left' } = request.params.arguments as any;
        
        const command = {
          action: 'send_mouse_click',
          x,
          y,
          button,
        };
        
        const response = await sendToElixir(command);
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

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('[Scenic MCP] Server started - ready to connect to Scenic applications');
}

main().catch((error) => {
  console.error('[Scenic MCP] Fatal error:', error);
  process.exit(1);
});
