#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, } from '@modelcontextprotocol/sdk/types.js';
import * as net from 'net';
import { spawn } from 'child_process';
// Generic MCP server for Scenic applications
const server = new Server({
    name: 'scenic-mcp',
    version: '0.2.0',
}, {
    capabilities: {
        tools: {},
    },
});
// Process management state
let managedProcess = null;
let processPath = null;
let processLogs = [];
const MAX_LOG_LINES = 1000;
// Helper function to check if TCP server is available
async function checkTCPServer(port = 9999) {
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
async function sendToElixir(command, retries = 3) {
    for (let i = 0; i < retries; i++) {
        try {
            return await attemptSendToElixir(command);
        }
        catch (error) {
            if (i === retries - 1)
                throw error;
            // Wait a bit before retrying
            await new Promise(resolve => setTimeout(resolve, 500));
        }
    }
    throw new Error('Failed to send command after retries');
}
async function attemptSendToElixir(command) {
    return new Promise((resolve, reject) => {
        const client = new net.Socket();
        let responseData = '';
        const timeout = setTimeout(() => {
            client.destroy();
            reject(new Error('Connection timeout'));
        }, 5000);
        client.connect(9999, 'localhost', () => {
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
            {
                name: 'inspect_viewport',
                description: 'Inspect the Scenic viewport to see what\'s currently displayed',
                inputSchema: {
                    type: 'object',
                    properties: {},
                },
            },
            {
                name: 'take_screenshot',
                description: 'Take a screenshot of the current Scenic application',
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
            {
                name: 'start_app',
                description: 'Start a Scenic application process',
                inputSchema: {
                    type: 'object',
                    properties: {
                        path: {
                            type: 'string',
                            description: 'Path to the Scenic application directory (default: /Users/luke/workbench/flx/quillex)',
                            default: '/Users/luke/workbench/flx/quillex',
                        },
                    },
                },
            },
            {
                name: 'stop_app',
                description: 'Stop the currently running Scenic application',
                inputSchema: {
                    type: 'object',
                    properties: {},
                },
            },
            {
                name: 'app_status',
                description: 'Get the status of the managed Scenic application process',
                inputSchema: {
                    type: 'object',
                    properties: {},
                },
            },
            {
                name: 'get_app_logs',
                description: 'Get recent logs from the Scenic application',
                inputSchema: {
                    type: 'object',
                    properties: {
                        lines: {
                            type: 'number',
                            description: 'Number of log lines to retrieve (default: 100)',
                            default: 100,
                        },
                    },
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
                const { port = 9999 } = request.params.arguments;
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
            }
            catch (error) {
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
            }
            catch (error) {
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
                const { text, key, modifiers } = request.params.arguments;
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
            }
            catch (error) {
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
                const { x, y } = request.params.arguments;
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
            }
            catch (error) {
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
                const { x, y, button = 'left' } = request.params.arguments;
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
            }
            catch (error) {
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
        case 'inspect_viewport': {
            try {
                const isRunning = await checkTCPServer();
                if (!isRunning) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: 'Cannot inspect viewport: Scenic TCP server is not running.',
                            },
                        ],
                        isError: true,
                    };
                }
                const command = {
                    action: 'get_scenic_graph',
                };
                const response = await sendToElixir(command);
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
                return {
                    content: [
                        {
                            type: 'text',
                            text: data.description || 'No viewport information available',
                        },
                    ],
                };
            }
            catch (error) {
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
        case 'start_app': {
            try {
                const { path: appPath = '/Users/luke/workbench/flx/quillex' } = request.params.arguments;
                // Check if a process is already running
                if (managedProcess && !managedProcess.killed) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: `A Scenic application is already running at ${processPath}. Stop it first before starting a new one.`,
                            },
                        ],
                        isError: true,
                    };
                }
                // Clear previous logs
                processLogs = [];
                // Start the Elixir application
                const env = { ...process.env, MIX_ENV: 'dev' };
                managedProcess = spawn('elixir', ['-S', 'mix', 'run', '--no-halt'], {
                    cwd: appPath,
                    env,
                    stdio: ['ignore', 'pipe', 'pipe'],
                });
                processPath = appPath;
                // Capture stdout
                if (managedProcess.stdout) {
                    managedProcess.stdout.on('data', (data) => {
                        const lines = data.toString().split('\n').filter((line) => line.trim());
                        processLogs.push(...lines);
                        // Keep only recent logs
                        if (processLogs.length > MAX_LOG_LINES) {
                            processLogs = processLogs.slice(-MAX_LOG_LINES);
                        }
                    });
                }
                // Capture stderr
                if (managedProcess.stderr) {
                    managedProcess.stderr.on('data', (data) => {
                        const lines = data.toString().split('\n').filter((line) => line.trim());
                        processLogs.push(...lines.map((line) => `[ERROR] ${line}`));
                        // Keep only recent logs
                        if (processLogs.length > MAX_LOG_LINES) {
                            processLogs = processLogs.slice(-MAX_LOG_LINES);
                        }
                    });
                }
                // Handle process events
                managedProcess.on('error', (err) => {
                    console.error(`[Scenic App] Process error: ${err}`);
                });
                managedProcess.on('exit', (code) => {
                    console.log(`[Scenic App] Process exited with code ${code}`);
                    processLogs.push(`[SYSTEM] Process exited with code ${code}`);
                    managedProcess = null;
                    processPath = null;
                });
                // Give the app a moment to start
                await new Promise(resolve => setTimeout(resolve, 2000));
                // Check if the process is still running
                if (!managedProcess || managedProcess.killed) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: 'Failed to start Scenic application - process exited immediately.',
                            },
                        ],
                        isError: true,
                    };
                }
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Scenic application started successfully!\nPath: ${appPath}\nPID: ${managedProcess.pid}\n\nWait a moment for the TCP server to initialize, then use connect_scenic to interact with it.`,
                        },
                    ],
                };
            }
            catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error starting app: ${error instanceof Error ? error.message : 'Unknown error'}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        case 'stop_app': {
            try {
                if (!managedProcess) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: 'No Scenic application is currently running.',
                            },
                        ],
                    };
                }
                // Send SIGTERM for graceful shutdown
                managedProcess.kill('SIGTERM');
                // Give it a moment to shut down gracefully
                await new Promise(resolve => setTimeout(resolve, 1000));
                // If still running, force kill
                if (!managedProcess.killed) {
                    managedProcess.kill('SIGKILL');
                }
                const stoppedPath = processPath;
                managedProcess = null;
                processPath = null;
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Scenic application stopped.\nPath: ${stoppedPath}`,
                        },
                    ],
                };
            }
            catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error stopping app: ${error instanceof Error ? error.message : 'Unknown error'}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        case 'app_status': {
            try {
                if (!managedProcess) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: 'Application Status: Stopped\nNo Scenic application is currently managed.',
                            },
                        ],
                    };
                }
                const isRunning = !managedProcess.killed;
                const tcpConnected = isRunning ? await checkTCPServer() : false;
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Application Status: ${isRunning ? 'Running' : 'Stopped'}\nPath: ${processPath}\nPID: ${managedProcess.pid}\nTCP Server: ${tcpConnected ? 'Connected' : 'Not Connected'}\n\n${tcpConnected ? 'The application is ready for scenic commands.' : 'Waiting for TCP server to initialize...'}`,
                        },
                    ],
                };
            }
            catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error getting status: ${error instanceof Error ? error.message : 'Unknown error'}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        case 'get_app_logs': {
            try {
                const { lines = 100 } = request.params.arguments;
                if (processLogs.length === 0) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: 'No logs available. Either no app is running or no output has been captured yet.',
                            },
                        ],
                    };
                }
                const recentLogs = processLogs.slice(-lines);
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Recent logs (${recentLogs.length} lines):\n\n${recentLogs.join('\n')}`,
                        },
                    ],
                };
            }
            catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error getting logs: ${error instanceof Error ? error.message : 'Unknown error'}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        case 'take_screenshot': {
            try {
                const isRunning = await checkTCPServer();
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
                const { format = 'path', filename } = request.params.arguments;
                const command = {
                    action: 'take_screenshot',
                    format,
                    filename,
                };
                const response = await sendToElixir(command);
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
                }
                else {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: `Screenshot saved to: ${data.path}`,
                            },
                        ],
                    };
                }
            }
            catch (error) {
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
//# sourceMappingURL=index.js.map