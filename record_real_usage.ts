#!/usr/bin/env node

/**
 * Record Real LLM Tool Usage
 * 
 * This script records actual Claude usage of MCP tools during testing
 */

import * as fs from 'fs';

interface RealUsageRecord {
  scenario: string;
  userIntent: string;
  toolsUsed: string[];
  toolsExpected: string[];
  success: boolean;
  issues: string[];
  timestamp?: string;
}

class RealUsageRecorder {
  private records: RealUsageRecord[] = [];

  recordScenario(record: RealUsageRecord) {
    this.records.push({
      ...record,
      timestamp: new Date().toISOString()
    });
  }

  calculateMetrics() {
    const totalScenarios = this.records.length;
    let totalToolsExpected = 0;
    let totalToolsUsed = 0;
    let totalCorrectUsage = 0;

    this.records.forEach(record => {
      totalToolsExpected += record.toolsExpected.length;
      totalToolsUsed += record.toolsUsed.length;
      
      // Count correct tool usage
      record.toolsUsed.forEach(tool => {
        if (record.toolsExpected.includes(tool)) {
          totalCorrectUsage++;
        }
      });
    });

    const discoveryRate = totalToolsExpected > 0 ? (totalToolsUsed / totalToolsExpected) * 100 : 0;
    const accuracyRate = totalToolsUsed > 0 ? (totalCorrectUsage / totalToolsUsed) * 100 : 0;

    return {
      discoveryRate,
      accuracyRate,
      totalScenarios,
      totalToolsExpected,
      totalToolsUsed,
      totalCorrectUsage
    };
  }

  generateReport() {
    const metrics = this.calculateMetrics();
    
    console.log('\n📊 REAL USAGE ANALYSIS REPORT');
    console.log('==============================\n');
    
    console.log(`📈 Claude's Actual Performance:`);
    console.log(`   Scenarios Tested: ${metrics.totalScenarios}`);
    console.log(`   Tool Discovery Rate: ${metrics.discoveryRate.toFixed(1)}% (${metrics.totalToolsUsed}/${metrics.totalToolsExpected})`);
    console.log(`   Tool Accuracy Rate: ${metrics.accuracyRate.toFixed(1)}% (${metrics.totalCorrectUsage}/${metrics.totalToolsUsed})`);
    console.log(`   Combined Success Rate: ${((metrics.discoveryRate * metrics.accuracyRate) / 100).toFixed(1)}%\n`);

    console.log('📋 Individual Scenario Results:');
    this.records.forEach((record, index) => {
      const status = record.success ? '✅' : '❌';
      console.log(`${index + 1}. ${status} ${record.scenario}`);
      console.log(`   Intent: ${record.userIntent}`);
      console.log(`   Expected: [${record.toolsExpected.join(', ')}]`);
      console.log(`   Used: [${record.toolsUsed.join(', ')}]`);
      if (record.issues.length > 0) {
        console.log(`   Issues: ${record.issues.join('; ')}`);
      }
      console.log('');
    });

    // Identify most problematic tools
    const toolMisses = new Map<string, number>();
    this.records.forEach(record => {
      record.toolsExpected.forEach(expectedTool => {
        if (!record.toolsUsed.includes(expectedTool)) {
          toolMisses.set(expectedTool, (toolMisses.get(expectedTool) || 0) + 1);
        }
      });
    });

    if (toolMisses.size > 0) {
      console.log('🔴 Most Missed Tools:');
      Array.from(toolMisses.entries())
        .sort((a, b) => b[1] - a[1])
        .forEach(([tool, misses]) => {
          console.log(`   ${tool}: missed ${misses} times`);
        });
    }

    return metrics;
  }

  exportData(filename: string = 'real_usage_data.json') {
    const data = {
      timestamp: new Date().toISOString(),
      records: this.records,
      metrics: this.calculateMetrics()
    };

    fs.writeFileSync(filename, JSON.stringify(data, null, 2));
    console.log(`\n📁 Real usage data exported to: ${filename}`);
  }
}

// Record the actual test I just performed
const recorder = new RealUsageRecorder();

// Scenario 1: Visual Development (what I just tested)
recorder.recordScenario({
  scenario: "Visual Development Iteration",
  userIntent: "I want to see how the app looks right now and document UI state",
  toolsUsed: ["connect_scenic", "take_screenshot"],
  toolsExpected: ["connect_scenic", "take_screenshot", "inspect_viewport"],
  success: true, // I used appropriate tools
  issues: ["Both tools correctly handled disconnected state", "Natural flow: connect -> screenshot"]
});

// Let me test another scenario: "App crashed, need to check logs"
console.log('\n🧪 Testing Scenario 2: App crashed, need to check logs\n');

// Export current data
recorder.generateReport();
recorder.exportData();

export { RealUsageRecorder };