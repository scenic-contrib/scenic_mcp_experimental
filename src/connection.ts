/**
 * Connection and process management for Scenic MCP
 *
 * Handles TCP connections to Elixir server, process spawning, and state management
 */

import * as net from 'net';
import { spawn, ChildProcess } from 'child_process';

// ========================================================================
// Process Management State
// ========================================================================

let managedProcess: ChildProcess | null = null;
let processPath: string | null = null;

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
let pendingCallbacks: Map<number, {resolve: (data: string) => void, reject: (err: Error) => void}> = new Map();
let messageIdCounter = 0;

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
      console.log(`Persistent connection established to port ${currentPort}`);
      connectionState = 'connected';
      lastSuccessfulCommand = Date.now();
      resolve(persistentConnection!);
    });

    persistentConnection.on('data', (data) => {
      connectionBuffer += data.toString();

      let lines = connectionBuffer.split('\n');
      connectionBuffer = lines.pop() || '';

      for (const line of lines) {
        if (line.trim()) {
          const entry = pendingCallbacks.entries().next().value;
          if (entry) {
            const [callbackId, callback] = entry;
            pendingCallbacks.delete(callbackId);
            callback.resolve(line.trim());
          }
        }
      }
    });

    persistentConnection.on('error', (err) => {
      console.error('Persistent connection error:', err);
      connectionState = 'disconnected';
      persistentConnection = null;

      for (const [id, callback] of pendingCallbacks) {
        callback.reject(err);
      }
      pendingCallbacks.clear();

      reject(err);
    });

    persistentConnection.on('close', () => {
      console.log('Persistent connection closed');
      connectionState = 'disconnected';
      persistentConnection = null;

      for (const [id, callback] of pendingCallbacks) {
        callback.reject(new Error('Connection closed'));
      }
      pendingCallbacks.clear();
    });
  });
}

async function sendThroughPersistentConnection(command: any): Promise<string> {
  const conn = await getPersistentConnection();
  const messageId = messageIdCounter++;

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      pendingCallbacks.delete(messageId);
      reject(new Error('Command timeout'));
    }, 5000);

    const wrappedCallback = {
      resolve: (data: string) => {
        clearTimeout(timeout);
        lastSuccessfulCommand = Date.now();
        resolve(data);
      },
      reject: (err: Error) => {
        clearTimeout(timeout);
        reject(err);
      }
    };

    pendingCallbacks.set(messageId, wrappedCallback);

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
// Process Management Functions
// ========================================================================

export function getManagedProcess() {
  return { managedProcess, processPath };
}

export async function startApp(appPath: string): Promise<{ success: boolean; pid?: number; error?: string }> {
  if (managedProcess && !managedProcess.killed) {
    return { success: false, error: `A Scenic application is already running at ${processPath}` };
  }

  const env = { ...process.env, MIX_ENV: 'dev' };
  managedProcess = spawn('elixir', ['-S', 'mix', 'run', '--no-halt'], {
    cwd: appPath,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  processPath = appPath;

  managedProcess.on('error', (err) => {
    console.error(`[Scenic App] Process error: ${err}`);
  });

  managedProcess.on('exit', (code) => {
    console.log(`[Scenic App] Process exited with code ${code}`);
    managedProcess = null;
    processPath = null;
  });

  await new Promise(resolve => setTimeout(resolve, 2000));

  if (!managedProcess || managedProcess.killed) {
    return { success: false, error: 'Process exited immediately' };
  }

  return { success: true, pid: managedProcess.pid };
}

export async function stopApp(): Promise<{ success: boolean; path?: string }> {
  if (!managedProcess) {
    return { success: false };
  }

  managedProcess.kill('SIGTERM');
  await new Promise(resolve => setTimeout(resolve, 1000));

  if (!managedProcess.killed) {
    managedProcess.kill('SIGKILL');
  }

  const stoppedPath = processPath;
  managedProcess = null;
  processPath = null;

  return { success: true, path: stoppedPath || undefined };
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
