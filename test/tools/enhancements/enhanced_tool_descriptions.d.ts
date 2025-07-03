/**
 * Enhanced Tool Descriptions for Scenic MCP
 *
 * This file contains improved tool descriptions designed to increase
 * LLM discovery and correct usage rates.
 */
export declare const enhancedToolDescriptions: ({
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            format: {
                type: string;
                enum: string[];
                description: string;
                default: string;
            };
            filename: {
                type: string;
                description: string;
            };
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            text: {
                type: string;
                description: string;
            };
            key: {
                type: string;
                description: string;
            };
            modifiers: {
                type: string;
                items: {
                    type: string;
                    enum: string[];
                };
                description: string;
            };
            format?: undefined;
            filename?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            x: {
                type: string;
                description: string;
            };
            y: {
                type: string;
                description: string;
            };
            button: {
                type: string;
                enum: string[];
                description: string;
                default: string;
            };
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required: string[];
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            x: {
                type: string;
                description: string;
            };
            y: {
                type: string;
                description: string;
            };
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required: string[];
    };
    useCases: string[];
    examples?: undefined;
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            port: {
                type: string;
                description: string;
                default: number;
            };
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required: never[];
    };
    useCases: string[];
    examples?: undefined;
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            path: {
                type: string;
                description: string;
            };
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            lines?: undefined;
        };
        required: string[];
    };
    useCases: string[];
    examples: string[];
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
            lines?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples?: undefined;
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            lines: {
                type: string;
                description: string;
                default: number;
            };
            format?: undefined;
            filename?: undefined;
            text?: undefined;
            key?: undefined;
            modifiers?: undefined;
            x?: undefined;
            y?: undefined;
            button?: undefined;
            port?: undefined;
            path?: undefined;
        };
        required?: undefined;
    };
    useCases: string[];
    examples: string[];
})[];
/**
 * Tool Selection Guide for LLMs
 */
export declare const toolSelectionGuide: {
    visual: {
        "see what's on screen": string[];
        "capture current state": string[];
        "document progress": string[];
        "debug visual issues": string[];
        "understand UI layout": string[];
    };
    interaction: {
        "type text": string[];
        "press keys": string[];
        "click button": string[];
        "navigate menu": string[];
        "test input": string[];
    };
    setup: {
        "start working with app": string[];
        "begin session": string[];
        "check connection": string[];
        "launch app": string[];
    };
    debugging: {
        "app crashed": string[];
        "check logs": string[];
        troubleshoot: string[];
        "monitor app": string[];
    };
};
//# sourceMappingURL=enhanced_tool_descriptions.d.ts.map