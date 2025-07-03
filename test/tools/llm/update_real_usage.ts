#!/usr/bin/env node

/**
 * Update real usage data with additional test scenarios
 */

import * as fs from 'fs';

const additionalTests = [
  {
    scenario: "Process Management and Logs",
    userIntent: "App crashed, need to check what happened and see logs",
    toolsUsed: ["app_status", "get_app_logs"],
    toolsExpected: ["app_status", "get_app_logs"],
    success: true,
    issues: ["Perfect tool selection for debugging"]
  },
  {
    scenario: "App Startup and Connection", 
    userIntent: "Start Quillex text editor for development",
    toolsUsed: ["start_app", "connect_scenic"],
    toolsExpected: ["start_app", "connect_scenic"],
    success: true,
    issues: ["Logical flow: start then connect"]
  },
  {
    scenario: "Interactive Development Session",
    userIntent: "See what's on screen in the running text editor, document with screenshot",
    toolsUsed: ["take_screenshot", "inspect_viewport"],
    toolsExpected: ["inspect_viewport", "take_screenshot", "connect_scenic"],
    success: true, 
    issues: ["Used key visual tools, connection already established"]
  }
];

// Calculate updated metrics
let totalToolsExpected = 9; // From first test: 3 + 2 + 2 + 3 = 10 wait let me recalculate
totalToolsExpected = 3 + 2 + 2 + 3; // 10 total expected tools across 4 scenarios

let totalToolsUsed = 8; // 2 + 2 + 2 + 2 = 8 tools actually used

let totalCorrectUsage = 8; // All tools used were correct

const discoveryRate = (totalToolsUsed / totalToolsExpected) * 100; // 80%
const accuracyRate = (totalCorrectUsage / totalToolsUsed) * 100; // 100%

console.log('\n📊 UPDATED REAL USAGE BASELINE');
console.log('===============================\n');

console.log(`📈 Claude's Baseline Performance (Before Enhancements):`);
console.log(`   Scenarios Tested: 4`);
console.log(`   Tool Discovery Rate: ${discoveryRate.toFixed(1)}%`);
console.log(`   Tool Accuracy Rate: ${accuracyRate.toFixed(1)}%`);
console.log(`   Combined Success Rate: ${((discoveryRate * accuracyRate) / 100).toFixed(1)}%\n`);

console.log('📋 Test Results Summary:');
console.log('1. ✅ Visual Development: connect_scenic + take_screenshot (missed inspect_viewport)');
console.log('2. ✅ Process Management: app_status + get_app_logs (perfect)');
console.log('3. ✅ App Startup: start_app + connect_scenic (perfect)');
console.log('4. ✅ Interactive Development: take_screenshot + inspect_viewport (good)\n');

console.log('🎯 Baseline Insights:');
console.log('• Claude naturally discovers most relevant tools');
console.log('• 100% accuracy when tools are used');
console.log('• Missing some supplementary tools (inspect_viewport in scenario 1)');
console.log('• Good logical flow in tool sequencing');
console.log('• Room for improvement: 80% -> 90%+ discovery rate\n');

// Export updated baseline
const baselineData = {
  timestamp: new Date().toISOString(),
  phase: 'baseline',
  scenarios: 4,
  metrics: {
    discoveryRate,
    accuracyRate,
    combinedSuccess: (discoveryRate * accuracyRate) / 100,
    totalToolsExpected,
    totalToolsUsed,
    totalCorrectUsage
  },
  tests: additionalTests
};

fs.writeFileSync('baseline_metrics.json', JSON.stringify(baselineData, null, 2));
console.log('📁 Baseline metrics saved to baseline_metrics.json');
console.log('\n🔧 Ready to apply enhancements and re-test!');