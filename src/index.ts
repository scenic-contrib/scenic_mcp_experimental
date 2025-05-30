#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import * as net from 'net';

// Simple MCP server for Scenic applications
const server = new Server(
  {
    name: 'scenic-mcp',
    version: '0.1.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper function to connect to Elixir TCP server
async function connectToElixir(): Promise<string> {
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let responseData = '';
    
    const timeout = setTimeout(() => {
      client.destroy();
      reject(new Error('Connection timeout'));
    }, 5000);
    
    client.connect(9999, 'localhost', () => {
      console.error('Connected to Elixir TCP server');
      client.write('hello\n');
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
        name: 'hello_scenic',
        description: 'Test communication with Scenic MCP server',
        inputSchema: {
          type: 'object',
          properties: {},
          required: [],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name } = request.params;

  switch (name) {
    case 'hello_scenic': {
      try {
        const response = await connectToElixir();
        const data = JSON.parse(response);
        
        return {
          content: [
            {
              type: 'text',
              text: `Connected to Scenic MCP!\n\nResponse from Elixir:\n${JSON.stringify(data, null, 2)}`,
            },
          ],
        };
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error connecting to Scenic MCP server: ${error instanceof Error ? error.message : 'Unknown error'}\n\nMake sure the Elixir TCP server is running on port 9999.`,
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
  console.error('Scenic MCP server started');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
