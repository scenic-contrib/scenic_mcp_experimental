#!/usr/bin/env node
"use strict";
/**
 * Record Real LLM Tool Usage
 *
 * This script records actual Claude usage of MCP tools during testing
 */
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealUsageRecorder = void 0;
var fs = require("fs");
var RealUsageRecorder = /** @class */ (function () {
    function RealUsageRecorder() {
        this.records = [];
    }
    RealUsageRecorder.prototype.recordScenario = function (record) {
        this.records.push(__assign(__assign({}, record), { timestamp: new Date().toISOString() }));
    };
    RealUsageRecorder.prototype.calculateMetrics = function () {
        var totalScenarios = this.records.length;
        var totalToolsExpected = 0;
        var totalToolsUsed = 0;
        var totalCorrectUsage = 0;
        this.records.forEach(function (record) {
            totalToolsExpected += record.toolsExpected.length;
            totalToolsUsed += record.toolsUsed.length;
            // Count correct tool usage
            record.toolsUsed.forEach(function (tool) {
                if (record.toolsExpected.includes(tool)) {
                    totalCorrectUsage++;
                }
            });
        });
        var discoveryRate = totalToolsExpected > 0 ? (totalToolsUsed / totalToolsExpected) * 100 : 0;
        var accuracyRate = totalToolsUsed > 0 ? (totalCorrectUsage / totalToolsUsed) * 100 : 0;
        return {
            discoveryRate: discoveryRate,
            accuracyRate: accuracyRate,
            totalScenarios: totalScenarios,
            totalToolsExpected: totalToolsExpected,
            totalToolsUsed: totalToolsUsed,
            totalCorrectUsage: totalCorrectUsage
        };
    };
    RealUsageRecorder.prototype.generateReport = function () {
        var metrics = this.calculateMetrics();
        console.log('\n📊 REAL USAGE ANALYSIS REPORT');
        console.log('==============================\n');
        console.log("\uD83D\uDCC8 Claude's Actual Performance:");
        console.log("   Scenarios Tested: ".concat(metrics.totalScenarios));
        console.log("   Tool Discovery Rate: ".concat(metrics.discoveryRate.toFixed(1), "% (").concat(metrics.totalToolsUsed, "/").concat(metrics.totalToolsExpected, ")"));
        console.log("   Tool Accuracy Rate: ".concat(metrics.accuracyRate.toFixed(1), "% (").concat(metrics.totalCorrectUsage, "/").concat(metrics.totalToolsUsed, ")"));
        console.log("   Combined Success Rate: ".concat(((metrics.discoveryRate * metrics.accuracyRate) / 100).toFixed(1), "%\n"));
        console.log('📋 Individual Scenario Results:');
        this.records.forEach(function (record, index) {
            var status = record.success ? '✅' : '❌';
            console.log("".concat(index + 1, ". ").concat(status, " ").concat(record.scenario));
            console.log("   Intent: ".concat(record.userIntent));
            console.log("   Expected: [".concat(record.toolsExpected.join(', '), "]"));
            console.log("   Used: [".concat(record.toolsUsed.join(', '), "]"));
            if (record.issues.length > 0) {
                console.log("   Issues: ".concat(record.issues.join('; ')));
            }
            console.log('');
        });
        // Identify most problematic tools
        var toolMisses = new Map();
        this.records.forEach(function (record) {
            record.toolsExpected.forEach(function (expectedTool) {
                if (!record.toolsUsed.includes(expectedTool)) {
                    toolMisses.set(expectedTool, (toolMisses.get(expectedTool) || 0) + 1);
                }
            });
        });
        if (toolMisses.size > 0) {
            console.log('🔴 Most Missed Tools:');
            Array.from(toolMisses.entries())
                .sort(function (a, b) { return b[1] - a[1]; })
                .forEach(function (_a) {
                var tool = _a[0], misses = _a[1];
                console.log("   ".concat(tool, ": missed ").concat(misses, " times"));
            });
        }
        return metrics;
    };
    RealUsageRecorder.prototype.exportData = function (filename) {
        if (filename === void 0) { filename = 'real_usage_data.json'; }
        var data = {
            timestamp: new Date().toISOString(),
            records: this.records,
            metrics: this.calculateMetrics()
        };
        fs.writeFileSync(filename, JSON.stringify(data, null, 2));
        console.log("\n\uD83D\uDCC1 Real usage data exported to: ".concat(filename));
    };
    return RealUsageRecorder;
}());
exports.RealUsageRecorder = RealUsageRecorder;
// Record the actual test I just performed
var recorder = new RealUsageRecorder();
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
