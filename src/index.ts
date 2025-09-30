#!/usr/bin/env node

/**
 * Scenic MCP Server - Main entry point
 *
 * This is a thin server that handles MCP protocol setup and delegates
 * all tool-related logic to the tools module.
 *
 * MCP Client (Claude Desktop) → TypeScript Server (this file) → TCP Bridge → Elixir Server → Scenic ViewPort
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { getToolDefinitions, handleToolCall } from './tools.js';
import { closePersistentConnection } from './connection.js';

// ========================================================================
// Server Setup
// ========================================================================

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

// ========================================================================
// Request Handlers
// ========================================================================

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: getToolDefinitions(),
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  return await handleToolCall(name, args);
});

// ========================================================================
// Server Startup
// ========================================================================

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Handle graceful shutdown
  process.on('SIGTERM', () => {
    closePersistentConnection();
    process.exit(0);
  });

  process.on('SIGINT', () => {
    closePersistentConnection();
    process.exit(0);
  });

  console.error('[Scenic MCP] Server started - monitoring for Scenic applications');
}

main().catch((error) => {
  console.error('[Scenic MCP] Fatal error:', error);
  process.exit(1);
});
