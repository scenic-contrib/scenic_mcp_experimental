/**
 * Connection management for Scenic MCP
 *
 * Handles persistent TCP connections to Elixir server with simple request-response pattern.
 */

import * as net from 'net';

// ========================================================================
// Connection State Management
// ========================================================================

let connectionState: 'unknown' | 'connected' | 'disconnected' = 'unknown';
let lastConnectionCheck = 0;
let lastSuccessfulCommand = 0;
const CONNECTION_CACHE_TTL = 2000;
const COMMAND_SUCCESS_TTL = 10000;
let currentPort = 9999;

// ========================================================================
// Persistent Connection Management
// ========================================================================

let persistentConnection: net.Socket | null = null;
let connectionBuffer = '';

// ========================================================================
// Connection Functions
// ========================================================================

function getPersistentConnection(): Promise<net.Socket> {
  return new Promise((resolve, reject) => {
    if (persistentConnection && !persistentConnection.destroyed) {
      resolve(persistentConnection);
      return;
    }

    persistentConnection = new net.Socket();

    persistentConnection.connect(currentPort, 'localhost', () => {
      connectionState = 'connected';
      lastSuccessfulCommand = Date.now();
      resolve(persistentConnection!);
    });

    persistentConnection.on('error', (err) => {
      connectionState = 'disconnected';
      persistentConnection = null;
      reject(err);
    });

    persistentConnection.on('close', () => {
      connectionState = 'disconnected';
      persistentConnection = null;
    });
  });
}

async function sendThroughPersistentConnection(command: any): Promise<string> {
  const conn = await getPersistentConnection();

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Command timeout after 5000ms'));
    }, 5000);

    // Set up one-time data handler for this request
    const onData = (data: Buffer) => {
      connectionBuffer += data.toString();

      const lines = connectionBuffer.split('\n');

      // If we have at least one complete line, process it
      if (lines.length > 1) {
        const response = lines[0].trim();
        connectionBuffer = lines.slice(1).join('\n');

        clearTimeout(timeout);
        lastSuccessfulCommand = Date.now();

        // Remove this handler after getting response
        conn.off('data', onData);

        resolve(response);
      }
    };

    conn.on('data', onData);

    const message = typeof command === 'string' ? command : JSON.stringify(command);
    conn.write(message + '\n');
  });
}

export function closePersistentConnection() {
  if (persistentConnection && !persistentConnection.destroyed) {
    persistentConnection.destroy();
    persistentConnection = null;
  }
}

async function sendToElixir(command: any, retries = 3): Promise<string> {
  for (let i = 0; i < retries; i++) {
    try {
      return await sendThroughPersistentConnection(command);
    } catch (error) {
      if (i === retries - 1) throw error;
      if (persistentConnection) {
        persistentConnection.destroy();
        persistentConnection = null;
      }
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
  throw new Error('Failed to send command after retries');
}

async function checkTCPServer(port: number = 9999, useCache: boolean = true): Promise<boolean> {
  const now = Date.now();

  if (useCache && now - lastSuccessfulCommand < COMMAND_SUCCESS_TTL) {
    return true;
  }

  if (useCache && now - lastConnectionCheck < CONNECTION_CACHE_TTL) {
    return connectionState === 'connected';
  }

  const isConnected = await performTCPCheck(port);
  lastConnectionCheck = now;

  const previousState = connectionState;
  connectionState = isConnected ? 'connected' : 'disconnected';

  if (previousState !== connectionState && previousState !== 'unknown') {
    console.error(`[Scenic MCP] Connection state changed: ${previousState} -> ${connectionState}`);
  }

  return isConnected;
}

async function performTCPCheck(port: number = 9999): Promise<boolean> {
  if (persistentConnection && !persistentConnection.destroyed) {
    return true;
  }

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

// ========================================================================
// Connection Context - Exported to tools
// ========================================================================

export interface ConnectionContext {
  sendToElixir: (command: any, retries?: number) => Promise<string>;
  checkTCPServer: (port?: number, useCache?: boolean) => Promise<boolean>;
  setCurrentPort: (port: number) => void;
  getCurrentPort: () => number;
}

export function getConnectionContext(): ConnectionContext {
  return {
    sendToElixir,
    checkTCPServer,
    setCurrentPort: (port: number) => {
      if (port !== currentPort) {
        closePersistentConnection();
      }
      currentPort = port;
    },
    getCurrentPort: () => currentPort,
  };
}
