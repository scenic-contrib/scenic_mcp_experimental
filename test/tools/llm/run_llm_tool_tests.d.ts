#!/usr/bin/env node
/**
 * Comprehensive LLM Tool Testing Suite for Scenic MCP
 *
 * This script runs end-to-end tests to measure and improve how well
 * LLMs discover and use the available MCP tools.
 */
declare class LLMToolTestRunner {
    private resultsDir;
    private currentSession;
    constructor();
    runFullTestSuite(): Promise<void>;
    private runBaselineTests;
    private applyEnhancements;
    private runEnhancedTests;
    private generateComparisonReport;
    private buildEnhancements;
    private applyDescriptionEnhancements;
    private simulateBaselineResults;
    private simulateEnhancedResults;
    private exportResults;
    private ensureResultsDir;
    private generateSessionId;
}
declare class ManualTestInstructions {
    static printInstructions(): void;
}
export { LLMToolTestRunner, ManualTestInstructions };
//# sourceMappingURL=run_llm_tool_tests.d.ts.map