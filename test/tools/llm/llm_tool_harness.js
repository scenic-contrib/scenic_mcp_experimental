#!/usr/bin/env node
/**
 * LLM Tool Usage Test Harness for Scenic MCP
 *
 * This harness creates realistic development scenarios and tests how well
 * LLMs can discover and use the available MCP tools correctly.
 *
 * Key Goals:
 * 1. Measure tool usage success rates
 * 2. Identify which tools are underutilized
 * 3. Test scenario-based tool selection
 * 4. Guide improvements to tool descriptions and documentation
 */
import * as fs from 'fs';
class LLMToolHarness {
    metrics = new Map();
    scenarios = [];
    testResults = [];
    constructor() {
        this.initializeScenarios();
    }
    initializeScenarios() {
        this.scenarios = [
            {
                name: "Visual Development Iteration",
                description: "Developer is building a Scenic GUI and needs to see visual progress during development",
                context: `You are helping a developer build a Scenic application. They've made some UI changes and want to see how it looks. They mention wanting to "see what the app looks like now" and "check if the layout is correct". The app is already running.`,
                expectedTools: ["take_screenshot", "inspect_viewport", "get_scenic_status"],
                criticalTools: ["take_screenshot"],
            },
            {
                name: "UI Testing and Validation",
                description: "Testing interactive elements by clicking and typing",
                context: `The developer has a form with input fields and buttons. They want to test if clicking the submit button works and if text input is properly handled. The app is running and you can see a login form on screen.`,
                expectedTools: ["inspect_viewport", "send_mouse_click", "send_keys", "take_screenshot"],
                criticalTools: ["send_mouse_click", "send_keys"],
            },
            {
                name: "Debugging Visual Issues",
                description: "Something looks wrong on screen and needs investigation",
                context: `The developer says "the button appears to be in the wrong place" and "the text seems cut off". They need help understanding what's currently displayed and what might be causing the layout issues.`,
                expectedTools: ["take_screenshot", "inspect_viewport", "get_scenic_status"],
                criticalTools: ["take_screenshot", "inspect_viewport"],
            },
            {
                name: "App Startup and Connection",
                description: "Getting a Scenic app running and connected for development",
                context: `You need to help start a Scenic application located at ./quillex and then connect to it for development. The developer wants to begin testing their text editor app.`,
                expectedTools: ["start_app", "connect_scenic", "get_scenic_status", "get_app_logs"],
                criticalTools: ["start_app", "connect_scenic"],
            },
            {
                name: "Process Management and Logs",
                description: "Managing the development process and checking for errors",
                context: `The Scenic app seems to have crashed or is behaving strangely. The developer needs to check what happened, see recent logs, and possibly restart the application.`,
                expectedTools: ["app_status", "get_app_logs", "stop_app", "start_app"],
                criticalTools: ["get_app_logs", "app_status"],
            },
            {
                name: "Interactive Development Session",
                description: "Full development workflow with visual feedback",
                context: `You're helping build a text editor. The developer wants to open the app, see what's on screen, try typing some text, take a screenshot to document progress, and then make some navigation tests using keyboard shortcuts.`,
                expectedTools: ["connect_scenic", "inspect_viewport", "send_keys", "take_screenshot", "send_mouse_click"],
                criticalTools: ["inspect_viewport", "send_keys", "take_screenshot"],
            },
            {
                name: "Documentation and Progress Tracking",
                description: "Creating visual documentation of development progress",
                context: `The developer is working on UI improvements and wants to create before/after screenshots for documentation. They've made changes and want to capture the current state visually to include in their project documentation.`,
                expectedTools: ["take_screenshot", "inspect_viewport"],
                criticalTools: ["take_screenshot"],
            }
        ];
        // Initialize metrics for each tool
        const allTools = [
            "connect_scenic", "get_scenic_status", "inspect_viewport", "take_screenshot",
            "send_keys", "send_mouse_move", "send_mouse_click",
            "start_app", "stop_app", "app_status", "get_app_logs"
        ];
        allTools.forEach(tool => {
            this.metrics.set(tool, {
                toolName: tool,
                scenario: "",
                expectedUsage: 0,
                actualUsage: 0,
                correctUsage: 0,
                missedOpportunities: []
            });
        });
    }
    async runAllScenarios() {
        console.log('🧪 Starting LLM Tool Usage Test Harness\n');
        console.log('This harness tests how well LLMs discover and use Scenic MCP tools\n');
        for (const scenario of this.scenarios) {
            await this.runScenario(scenario);
        }
        this.generateToolUsageReport();
        this.generateRecommendations();
    }
    async runScenario(scenario) {
        console.log(`\n📝 Scenario: ${scenario.name}`);
        console.log(`Description: ${scenario.description}`);
        console.log(`Context: ${scenario.context}\n`);
        // Update expected usage counts
        scenario.expectedTools.forEach(tool => {
            const metric = this.metrics.get(tool);
            if (metric) {
                metric.expectedUsage++;
            }
        });
        // This is where we would integrate with an LLM to test tool usage
        // For now, we'll simulate and provide structure for manual testing
        console.log(`Expected tools for this scenario:`);
        scenario.expectedTools.forEach(tool => {
            const isCritical = scenario.criticalTools.includes(tool);
            console.log(`  ${isCritical ? '🔥' : '📋'} ${tool} ${isCritical ? '(CRITICAL)' : ''}`);
        });
        console.log(`\n💡 Test this scenario by:`);
        console.log(`1. Present this context to Claude/LLM`);
        console.log(`2. See which tools they naturally use`);
        console.log(`3. Record results using recordToolUsage() method`);
        console.log(`4. Note any missed opportunities\n`);
    }
    // Method to record actual tool usage during testing
    recordToolUsage(toolName, scenario, wasCorrect = true) {
        const metric = this.metrics.get(toolName);
        if (metric) {
            metric.actualUsage++;
            if (wasCorrect) {
                metric.correctUsage++;
            }
            metric.scenario = scenario;
        }
    }
    recordMissedOpportunity(toolName, scenario, reason) {
        const metric = this.metrics.get(toolName);
        if (metric) {
            metric.missedOpportunities.push(`${scenario}: ${reason}`);
        }
    }
    generateToolUsageReport() {
        console.log('\n📊 Tool Usage Analysis Report');
        console.log('=====================================\n');
        // Calculate overall statistics
        let totalExpected = 0;
        let totalActual = 0;
        let totalCorrect = 0;
        this.metrics.forEach(metric => {
            totalExpected += metric.expectedUsage;
            totalActual += metric.actualUsage;
            totalCorrect += metric.correctUsage;
        });
        const discoveryRate = totalExpected > 0 ? (totalActual / totalExpected) * 100 : 0;
        const accuracyRate = totalActual > 0 ? (totalCorrect / totalActual) * 100 : 0;
        console.log(`📈 Overall Statistics:`);
        console.log(`   Tool Discovery Rate: ${discoveryRate.toFixed(1)}% (${totalActual}/${totalExpected})`);
        console.log(`   Tool Usage Accuracy: ${accuracyRate.toFixed(1)}% (${totalCorrect}/${totalActual})`);
        console.log(`   Combined Success Rate: ${((discoveryRate * accuracyRate) / 100).toFixed(1)}%\n`);
        // Individual tool analysis
        console.log('🔧 Individual Tool Performance:');
        // Sort tools by performance issues (most problematic first)
        const sortedMetrics = Array.from(this.metrics.values()).sort((a, b) => {
            const aScore = a.expectedUsage > 0 ? (a.correctUsage / a.expectedUsage) : 1;
            const bScore = b.expectedUsage > 0 ? (b.correctUsage / b.expectedUsage) : 1;
            return aScore - bScore;
        });
        sortedMetrics.forEach(metric => {
            const discoveryRate = metric.expectedUsage > 0 ?
                (metric.actualUsage / metric.expectedUsage) * 100 : 0;
            const accuracyRate = metric.actualUsage > 0 ?
                (metric.correctUsage / metric.actualUsage) * 100 : 0;
            const status = discoveryRate < 50 ? '🔴' : discoveryRate < 80 ? '🟡' : '🟢';
            console.log(`${status} ${metric.toolName}:`);
            console.log(`     Discovery: ${discoveryRate.toFixed(0)}% (${metric.actualUsage}/${metric.expectedUsage})`);
            console.log(`     Accuracy: ${accuracyRate.toFixed(0)}% (${metric.correctUsage}/${metric.actualUsage})`);
            if (metric.missedOpportunities.length > 0) {
                console.log(`     Missed: ${metric.missedOpportunities.length} opportunities`);
                metric.missedOpportunities.forEach(missed => {
                    console.log(`       - ${missed}`);
                });
            }
            console.log('');
        });
    }
    generateRecommendations() {
        console.log('\n💡 Improvement Recommendations');
        console.log('===============================\n');
        // Find most problematic tools
        const problematicTools = Array.from(this.metrics.values())
            .filter(m => m.expectedUsage > 0 && (m.actualUsage / m.expectedUsage) < 0.7)
            .sort((a, b) => (a.actualUsage / a.expectedUsage) - (b.actualUsage / b.expectedUsage));
        if (problematicTools.length === 0) {
            console.log('🎉 Excellent! All tools are being discovered and used effectively.');
            return;
        }
        console.log('🔧 Priority Tools for Improvement:\n');
        problematicTools.forEach((metric, index) => {
            console.log(`${index + 1}. **${metric.toolName}** (${((metric.actualUsage / metric.expectedUsage) * 100).toFixed(0)}% discovery rate)`);
            // Generate specific recommendations based on tool type
            const recommendations = this.getToolRecommendations(metric.toolName);
            recommendations.forEach(rec => {
                console.log(`   • ${rec}`);
            });
            console.log('');
        });
        // General recommendations
        console.log('🌟 General Improvements:');
        console.log('• Add usage examples to tool descriptions');
        console.log('• Include common use cases in tool schemas');
        console.log('• Add contextual hints about when to use each tool');
        console.log('• Improve tool names to be more discoverable');
        console.log('• Add tool categories/tags for better organization');
    }
    getToolRecommendations(toolName) {
        const recommendations = {
            'take_screenshot': [
                'Add "visual documentation", "progress tracking" to description',
                'Include examples: "capture current UI state", "create before/after images"',
                'Emphasize use for debugging visual issues',
                'Mention both path and base64 output options clearly'
            ],
            'inspect_viewport': [
                'Clarify difference from take_screenshot (text description vs image)',
                'Add examples of when text description is better than image',
                'Mention use for accessibility and programmatic UI analysis'
            ],
            'send_keys': [
                'Add examples for both text input and special keys',
                'Include common keyboard shortcuts examples',
                'Clarify modifier key usage (ctrl+c, etc.)'
            ],
            'send_mouse_click': [
                'Emphasize coordinate-based clicking',
                'Add guidance on finding click coordinates',
                'Include examples of different button types'
            ],
            'start_app': [
                'Clarify path parameter requirements',
                'Add examples of typical Scenic app directory structures',
                'Mention startup time expectations'
            ],
            'get_app_logs': [
                'Emphasize debugging use case',
                'Add examples of what logs contain',
                'Mention line limit parameter'
            ]
        };
        return recommendations[toolName] || [
            'Review tool description for clarity',
            'Add practical usage examples',
            'Consider if tool name clearly indicates purpose'
        ];
    }
    // Export test data for external analysis
    exportTestData(filename = 'scenic_mcp_tool_analysis.json') {
        const exportData = {
            timestamp: new Date().toISOString(),
            scenarios: this.scenarios,
            metrics: Array.from(this.metrics.values()),
            testResults: this.testResults
        };
        fs.writeFileSync(filename, JSON.stringify(exportData, null, 2));
        console.log(`\n📁 Test data exported to: ${filename}`);
    }
}
// CLI interface and manual testing helpers
class ManualTestHelper {
    harness;
    constructor() {
        this.harness = new LLMToolHarness();
    }
    async runInteractiveTest() {
        console.log('🎯 Interactive Testing Mode');
        console.log('==========================\n');
        console.log('This mode helps you manually test scenarios with Claude/LLMs\n');
        // For now, just run the scenario descriptions
        await this.harness.runAllScenarios();
        console.log('\n📋 Manual Testing Instructions:');
        console.log('1. Copy each scenario context to Claude');
        console.log('2. See which MCP tools Claude chooses to use');
        console.log('3. Record results using the provided methods');
        console.log('4. Run generateReport() to see analysis\n');
        // Example of how to record results
        console.log('🔧 Example result recording:');
        console.log('harness.recordToolUsage("take_screenshot", "Visual Development Iteration", true);');
        console.log('harness.recordMissedOpportunity("take_screenshot", "Documentation", "LLM used inspect_viewport instead");');
    }
}
// Command line interface
async function main() {
    const args = process.argv.slice(2);
    const mode = args[0] || 'scenarios';
    switch (mode) {
        case 'scenarios':
            const harness = new LLMToolHarness();
            await harness.runAllScenarios();
            harness.exportTestData();
            break;
        case 'interactive':
            const helper = new ManualTestHelper();
            await helper.runInteractiveTest();
            break;
        default:
            console.log('Usage: node llm_tool_harness.js [scenarios|interactive]');
            console.log('  scenarios   - Run all test scenarios (default)');
            console.log('  interactive - Interactive testing mode');
    }
}
if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch(console.error);
}
export { LLMToolHarness, ManualTestHelper };
//# sourceMappingURL=llm_tool_harness.js.map