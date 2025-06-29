/**
 * Enhanced Tool Descriptions for Scenic MCP
 *
 * This file contains improved tool descriptions designed to increase
 * LLM discovery and correct usage rates.
 */
export const enhancedToolDescriptions = [
    {
        name: 'take_screenshot',
        description: 'VISUAL DOCUMENTATION: Capture screenshots of the Scenic application for development progress tracking, debugging UI issues, creating before/after comparisons, and documenting visual changes. Essential for visual development workflows.',
        inputSchema: {
            type: 'object',
            properties: {
                format: {
                    type: 'string',
                    enum: ['path', 'base64'],
                    description: 'Output format: "path" returns file location (for saving/sharing), "base64" returns image data (for immediate viewing)',
                    default: 'path',
                },
                filename: {
                    type: 'string',
                    description: 'Optional filename (auto-generated if omitted). Include .png extension or it will be added automatically.',
                },
            },
        },
        useCases: [
            'Developer wants to see current UI state',
            'Creating documentation with visual examples',
            'Debugging layout or visual rendering issues',
            'Tracking development progress with before/after images',
            'Sharing current app state with team members'
        ],
        examples: [
            'User says: "I want to see how the app looks now"',
            'User says: "Take a picture of the current screen"',
            'User says: "Capture this for documentation"',
            'User says: "Show me what\'s displayed"'
        ]
    },
    {
        name: 'inspect_viewport',
        description: 'UI ANALYSIS: Get a text-based description of what\'s currently displayed in the Scenic application. Perfect for programmatic UI analysis, accessibility checks, and when you need to understand UI structure without visual inspection.',
        inputSchema: {
            type: 'object',
            properties: {},
        },
        useCases: [
            'Understanding current UI elements and layout',
            'Programmatic analysis of interface structure',
            'Accessibility and screen reader compatibility',
            'Finding clickable elements and their positions',
            'Debugging when visual rendering is unclear'
        ],
        examples: [
            'User asks: "What\'s on screen right now?"',
            'User asks: "What buttons are available?"',
            'User asks: "Describe the current interface"',
            'Need to find coordinates for clicking elements'
        ]
    },
    {
        name: 'send_keys',
        description: 'KEYBOARD INPUT: Send text input or special keystrokes to the Scenic application. Use for typing text, navigation shortcuts, and testing keyboard interactions. Supports both regular text and special keys with modifiers.',
        inputSchema: {
            type: 'object',
            properties: {
                text: {
                    type: 'string',
                    description: 'Regular text to type (each character sent individually). Use for text input fields, typing content.',
                },
                key: {
                    type: 'string',
                    description: 'Special key names: enter, escape, tab, backspace, delete, space, up, down, left, right, home, end, page_up, page_down, f1-f12',
                },
                modifiers: {
                    type: 'array',
                    items: {
                        type: 'string',
                        enum: ['ctrl', 'shift', 'alt', 'cmd', 'meta'],
                    },
                    description: 'Modifier keys for combinations like Ctrl+C, Cmd+S, Shift+Tab',
                },
            },
        },
        useCases: [
            'Typing text into input fields or text editors',
            'Navigation using arrow keys or tab',
            'Keyboard shortcuts (Ctrl+C, Cmd+S, etc.)',
            'Testing text input functionality',
            'Menu navigation and form completion'
        ],
        examples: [
            'Type "hello world" → {text: "hello world"}',
            'Press Enter → {key: "enter"}',
            'Copy shortcut → {key: "c", modifiers: ["ctrl"]}',
            'Navigate up → {key: "up"}'
        ]
    },
    {
        name: 'send_mouse_click',
        description: 'MOUSE INTERACTION: Click at specific screen coordinates to interact with buttons, links, and UI elements. Use with inspect_viewport to find clickable elements and their positions.',
        inputSchema: {
            type: 'object',
            properties: {
                x: {
                    type: 'number',
                    description: 'X coordinate (horizontal position) - use inspect_viewport to find element positions',
                },
                y: {
                    type: 'number',
                    description: 'Y coordinate (vertical position) - use inspect_viewport to find element positions',
                },
                button: {
                    type: 'string',
                    enum: ['left', 'right', 'middle'],
                    description: 'Mouse button: "left" for normal clicks, "right" for context menus, "middle" for special actions',
                    default: 'left',
                },
            },
            required: ['x', 'y'],
        },
        useCases: [
            'Clicking buttons and interactive elements',
            'Testing UI element responsiveness',
            'Form submission and navigation',
            'Menu item selection',
            'Context menu access (right-click)'
        ],
        examples: [
            'Click a button at position (100, 50)',
            'Right-click for context menu at (200, 300)',
            'Test clickable element responsiveness'
        ]
    },
    {
        name: 'send_mouse_move',
        description: 'CURSOR MOVEMENT: Move the mouse cursor to specific coordinates. Useful for hover effects, precise positioning before clicking, and testing mouse-over interactions.',
        inputSchema: {
            type: 'object',
            properties: {
                x: {
                    type: 'number',
                    description: 'X coordinate to move cursor to',
                },
                y: {
                    type: 'number',
                    description: 'Y coordinate to move cursor to',
                },
            },
            required: ['x', 'y'],
        },
        useCases: [
            'Testing hover effects and tooltips',
            'Precise cursor positioning before clicking',
            'Mouse-over interaction testing',
            'Cursor-based UI element highlighting'
        ]
    },
    {
        name: 'connect_scenic',
        description: 'CONNECTION SETUP: Establish connection to a running Scenic application. ALWAYS use this first before other tools to ensure the app is reachable. Returns connection status and app information.',
        inputSchema: {
            type: 'object',
            properties: {
                port: {
                    type: 'number',
                    description: 'TCP port number (default: 9999)',
                    default: 9999,
                },
            },
        },
        useCases: [
            'First step in any Scenic interaction session',
            'Verifying app is running and accessible',
            'Connection troubleshooting',
            'Getting app status and information'
        ],
        examples: [
            'User wants to start working with Scenic app',
            'Need to verify connection before other operations',
            'Troubleshooting connectivity issues'
        ]
    },
    {
        name: 'get_scenic_status',
        description: 'CONNECTION STATUS: Check current connection status and get detailed information about the Scenic application and MCP server state.',
        inputSchema: {
            type: 'object',
            properties: {},
            required: [],
        },
        useCases: [
            'Verifying active connection',
            'Troubleshooting connection issues',
            'Getting app and server information',
            'Health check before operations'
        ]
    },
    {
        name: 'start_app',
        description: 'PROCESS MANAGEMENT: Launch a Scenic application from its directory path. Use when you need to start the app before connecting to it.',
        inputSchema: {
            type: 'object',
            properties: {
                path: {
                    type: 'string',
                    description: 'Absolute path to the Scenic application directory (containing mix.exs)',
                },
            },
            required: ['path'],
        },
        useCases: [
            'Starting a Scenic app for development',
            'Launching app from project directory',
            'Beginning development session',
            'Process management in development workflow'
        ],
        examples: [
            'User wants to start quillex app → {path: "/path/to/quillex"}',
            'Beginning development session with fresh app start'
        ]
    },
    {
        name: 'stop_app',
        description: 'PROCESS MANAGEMENT: Stop the currently managed Scenic application process. Use for cleanup or restarting apps.',
        inputSchema: {
            type: 'object',
            properties: {},
        },
        useCases: [
            'Stopping app for restart',
            'Cleanup after development session',
            'Process management',
            'Freeing resources'
        ]
    },
    {
        name: 'app_status',
        description: 'PROCESS MONITORING: Get status of the managed Scenic application process, including running state and connection info.',
        inputSchema: {
            type: 'object',
            properties: {},
        },
        useCases: [
            'Checking if app is still running',
            'Process health monitoring',
            'Debugging process issues',
            'Development workflow status'
        ]
    },
    {
        name: 'get_app_logs',
        description: 'DEBUGGING: Retrieve recent log output from the Scenic application. Essential for debugging crashes, errors, and understanding app behavior.',
        inputSchema: {
            type: 'object',
            properties: {
                lines: {
                    type: 'number',
                    description: 'Number of recent log lines to retrieve (default: 100)',
                    default: 100,
                },
            },
        },
        useCases: [
            'Debugging app crashes or errors',
            'Understanding app behavior and state',
            'Monitoring app output during development',
            'Troubleshooting unexpected behavior'
        ],
        examples: [
            'User reports: "the app crashed"',
            'User asks: "what\'s in the logs?"',
            'Debugging unexpected behavior',
            'Monitoring development progress'
        ]
    }
];
/**
 * Tool Selection Guide for LLMs
 */
export const toolSelectionGuide = {
    // Visual tasks
    visual: {
        "see what's on screen": ["take_screenshot", "inspect_viewport"],
        "capture current state": ["take_screenshot"],
        "document progress": ["take_screenshot"],
        "debug visual issues": ["take_screenshot", "inspect_viewport"],
        "understand UI layout": ["inspect_viewport"]
    },
    // Interaction tasks
    interaction: {
        "type text": ["send_keys"],
        "press keys": ["send_keys"],
        "click button": ["send_mouse_click"],
        "navigate menu": ["send_keys", "send_mouse_click"],
        "test input": ["send_keys", "send_mouse_click"]
    },
    // Connection and setup
    setup: {
        "start working with app": ["connect_scenic"],
        "begin session": ["start_app", "connect_scenic"],
        "check connection": ["get_scenic_status"],
        "launch app": ["start_app"]
    },
    // Debugging and monitoring
    debugging: {
        "app crashed": ["get_app_logs", "app_status"],
        "check logs": ["get_app_logs"],
        "troubleshoot": ["get_scenic_status", "get_app_logs"],
        "monitor app": ["app_status", "get_app_logs"]
    }
};
//# sourceMappingURL=enhanced_tool_descriptions.js.map