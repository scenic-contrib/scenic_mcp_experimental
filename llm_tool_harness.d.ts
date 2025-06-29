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
interface ToolUsageMetric {
    toolName: string;
    scenario: string;
    expectedUsage: number;
    actualUsage: number;
    correctUsage: number;
    missedOpportunities: string[];
}
interface ScenarioTest {
    name: string;
    description: string;
    context: string;
    expectedTools: string[];
    criticalTools: string[];
    setup?: () => Promise<void>;
    cleanup?: () => Promise<void>;
}
declare class LLMToolHarness {
    private metrics;
    private scenarios;
    private testResults;
    constructor();
    private initializeScenarios;
    runAllScenarios(): Promise<void>;
    private runScenario;
    recordToolUsage(toolName: string, scenario: string, wasCorrect?: boolean): void;
    recordMissedOpportunity(toolName: string, scenario: string, reason: string): void;
    private generateToolUsageReport;
    private generateRecommendations;
    private getToolRecommendations;
    exportTestData(filename?: string): void;
}
declare class ManualTestHelper {
    private harness;
    constructor();
    runInteractiveTest(): Promise<void>;
}
export { LLMToolHarness, ManualTestHelper, ScenarioTest, ToolUsageMetric };
//# sourceMappingURL=llm_tool_harness.d.ts.map