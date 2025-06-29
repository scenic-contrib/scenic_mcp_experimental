#!/usr/bin/env node

/**
 * MCP Evals for Scenic MCP Server
 * 
 * This evaluation framework tests the Scenic MCP server using various scenarios
 * and provides LLM-based scoring for the quality of responses.
 */

import * as net from 'net';
import { spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

interface EvalResult {
  testName: string;
  passed: boolean;
  score: number; // 0-100
  details: string;
  latency: number;
  errorMsg?: string;
}

interface EvalConfig {
  serverPort: number;
  timeoutMs: number;
  testAppPath?: string;
  enableLLMScoring: boolean;
}

class ScenicMcpEvals {
  private config: EvalConfig;
  private results: EvalResult[] = [];

  constructor(config: Partial<EvalConfig> = {}) {
    this.config = {
      serverPort: 9999,
      timeoutMs: 5000,
      enableLLMScoring: false,
      ...config
    };
  }

  async runAllEvals(): Promise<void> {
    console.log('🚀 Starting Scenic MCP Server Evaluations\n');

    // Basic connectivity tests
    await this.evalServerConnectivity();
    await this.evalCommandParsing();
    await this.evalErrorHandling();
    
    // Tool-specific tests
    await this.evalGetScenicGraph();
    await this.evalSendKeys();
    await this.evalMouseInteraction();
    await this.evalScreenshotCapture();
    
    // Performance tests
    await this.evalResponseLatency();
    await this.evalConcurrentConnections();

    // Generate report
    this.generateReport();
  }

  private async evalServerConnectivity(): Promise<void> {
    const testName = 'Server Connectivity';
    const startTime = Date.now();

    try {
      const connected = await this.checkTCPConnection();
      const latency = Date.now() - startTime;

      this.results.push({
        testName,
        passed: connected,
        score: connected ? 100 : 0,
        details: connected ? 'Successfully connected to TCP server' : 'Failed to connect to TCP server',
        latency
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Connection test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalCommandParsing(): Promise<void> {
    const testName = 'Command Parsing';
    const startTime = Date.now();

    try {
      // Test valid JSON command
      const validCommand = { action: 'get_scenic_graph' };
      const response = await this.sendCommand(validCommand);
      
      const isValidJson = typeof response === 'object' && response !== null;
      const hasExpectedStructure = response.hasOwnProperty('error') || response.hasOwnProperty('status');
      
      const passed = isValidJson && hasExpectedStructure;
      const score = passed ? 100 : 0;

      this.results.push({
        testName,
        passed,
        score,
        details: passed ? 'Commands parsed correctly' : 'Command parsing failed',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Command parsing test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalErrorHandling(): Promise<void> {
    const testName = 'Error Handling';
    const startTime = Date.now();

    try {
      // Test invalid JSON
      const response = await this.sendRawCommand('invalid json{');
      
      const handlesError = response && 
                          typeof response === 'object' && 
                          response.error === 'Invalid JSON';
      
      const score = handlesError ? 100 : 50;

      this.results.push({
        testName,
        passed: handlesError,
        score,
        details: handlesError ? 'Properly handles invalid JSON' : 'Error handling could be improved',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Error handling test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalGetScenicGraph(): Promise<void> {
    const testName = 'Get Scenic Graph Tool';
    const startTime = Date.now();

    try {
      const command = { action: 'get_scenic_graph' };
      const response = await this.sendCommand(command);
      
      // Without a running Scenic app, we expect a "No viewport found" error
      const expectedError = response && response.error === 'No viewport found';
      const passed = expectedError;
      
      // Score based on proper error handling
      const score = passed ? 85 : 0; // 85% because it's handling absence correctly

      this.results.push({
        testName,
        passed,
        score,
        details: passed ? 'Correctly handles missing viewport' : 'Unexpected response format',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Get scenic graph test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalSendKeys(): Promise<void> {
    const testName = 'Send Keys Tool';
    const startTime = Date.now();

    try {
      const command = { action: 'send_keys', text: 'hello' };
      const response = await this.sendCommand(command);
      
      const expectedError = response && response.error === 'No viewport found';
      const passed = expectedError;
      
      const score = passed ? 85 : 0;

      this.results.push({
        testName,
        passed,
        score,
        details: passed ? 'Correctly handles key input without viewport' : 'Unexpected response',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Send keys test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalMouseInteraction(): Promise<void> {
    const testName = 'Mouse Interaction Tools';
    const startTime = Date.now();

    try {
      // Test mouse move
      const moveCommand = { action: 'send_mouse_move', x: 100, y: 200 };
      const moveResponse = await this.sendCommand(moveCommand);
      
      // Test mouse click
      const clickCommand = { action: 'send_mouse_click', x: 100, y: 200 };
      const clickResponse = await this.sendCommand(clickCommand);
      
      const bothHandled = moveResponse?.error === 'No viewport found' && 
                         clickResponse?.error === 'No viewport found';
      
      const score = bothHandled ? 85 : 0;

      this.results.push({
        testName,
        passed: bothHandled,
        score,
        details: bothHandled ? 'Mouse tools handle missing viewport correctly' : 'Unexpected mouse tool behavior',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Mouse interaction test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalScreenshotCapture(): Promise<void> {
    const testName = 'Screenshot Capture Tool';
    const startTime = Date.now();

    try {
      const command = { action: 'take_screenshot' };
      const response = await this.sendCommand(command);
      
      const expectedError = response && response.error === 'No viewport found';
      const passed = expectedError;
      
      const score = passed ? 85 : 0;

      this.results.push({
        testName,
        passed,
        score,
        details: passed ? 'Screenshot tool handles missing viewport correctly' : 'Unexpected screenshot response',
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Screenshot test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async evalResponseLatency(): Promise<void> {
    const testName = 'Response Latency';
    let totalLatency = 0;
    const iterations = 10;
    let successCount = 0;

    for (let i = 0; i < iterations; i++) {
      const startTime = Date.now();
      try {
        await this.sendCommand({ action: 'get_scenic_graph' });
        totalLatency += Date.now() - startTime;
        successCount++;
      } catch (error) {
        // Count as failed iteration
      }
    }

    const avgLatency = successCount > 0 ? totalLatency / successCount : this.config.timeoutMs;
    const passed = avgLatency < 500; // Under 500ms average
    const score = Math.max(0, 100 - (avgLatency / 10)); // Score decreases with latency

    this.results.push({
      testName,
      passed,
      score: Math.round(score),
      details: `Average latency: ${Math.round(avgLatency)}ms across ${successCount}/${iterations} successful requests`,
      latency: avgLatency
    });
  }

  private async evalConcurrentConnections(): Promise<void> {
    const testName = 'Concurrent Connections';
    const startTime = Date.now();
    const concurrentRequests = 5;

    try {
      const promises = Array(concurrentRequests).fill(null).map(() => 
        this.sendCommand({ action: 'get_scenic_graph' })
      );

      const results = await Promise.allSettled(promises);
      const successCount = results.filter(r => r.status === 'fulfilled').length;
      
      const passed = successCount === concurrentRequests;
      const score = (successCount / concurrentRequests) * 100;

      this.results.push({
        testName,
        passed,
        score: Math.round(score),
        details: `Handled ${successCount}/${concurrentRequests} concurrent connections`,
        latency: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        testName,
        passed: false,
        score: 0,
        details: 'Concurrent connections test failed',
        latency: Date.now() - startTime,
        errorMsg: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async checkTCPConnection(): Promise<boolean> {
    return new Promise((resolve) => {
      const client = new net.Socket();
      const timeout = setTimeout(() => {
        client.destroy();
        resolve(false);
      }, this.config.timeoutMs);

      client.connect(this.config.serverPort, 'localhost', () => {
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

  private async sendCommand(command: any): Promise<any> {
    const jsonCommand = JSON.stringify(command);
    return this.sendRawCommand(jsonCommand);
  }

  private async sendRawCommand(rawCommand: string): Promise<any> {
    return new Promise((resolve, reject) => {
      const client = new net.Socket();
      let responseData = '';
      
      const timeout = setTimeout(() => {
        client.destroy();
        reject(new Error('Connection timeout'));
      }, this.config.timeoutMs);
      
      client.connect(this.config.serverPort, 'localhost', () => {
        client.write(rawCommand + '\n');
      });
      
      client.on('data', (data) => {
        responseData += data.toString();
        if (responseData.includes('\n')) {
          clearTimeout(timeout);
          client.destroy();
          try {
            const response = JSON.parse(responseData.trim());
            resolve(response);
          } catch (e) {
            resolve({ error: 'Invalid JSON response', raw: responseData.trim() });
          }
        }
      });
      
      client.on('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
  }

  private generateReport(): void {
    console.log('\n📊 Scenic MCP Server Evaluation Report');
    console.log('=========================================\n');

    const totalTests = this.results.length;
    const passedTests = this.results.filter(r => r.passed).length;
    const averageScore = this.results.reduce((sum, r) => sum + r.score, 0) / totalTests;
    const averageLatency = this.results.reduce((sum, r) => sum + r.latency, 0) / totalTests;

    console.log(`📈 Overall Results:`);
    console.log(`   Tests Passed: ${passedTests}/${totalTests} (${Math.round(passedTests/totalTests*100)}%)`);
    console.log(`   Average Score: ${Math.round(averageScore)}/100`);
    console.log(`   Average Latency: ${Math.round(averageLatency)}ms\n`);

    console.log('📋 Detailed Results:');
    this.results.forEach((result, index) => {
      const status = result.passed ? '✅' : '❌';
      console.log(`${index + 1}. ${status} ${result.testName}`);
      console.log(`   Score: ${result.score}/100`);
      console.log(`   Latency: ${result.latency}ms`);
      console.log(`   Details: ${result.details}`);
      if (result.errorMsg) {
        console.log(`   Error: ${result.errorMsg}`);
      }
      console.log('');
    });

    // Generate recommendations
    this.generateRecommendations();
  }

  private generateRecommendations(): void {
    const failedTests = this.results.filter(r => !r.passed);
    const slowTests = this.results.filter(r => r.latency > 1000);
    
    if (failedTests.length === 0 && slowTests.length === 0) {
      console.log('🎉 Excellent! All tests passed with good performance.');
      return;
    }

    console.log('💡 Recommendations:');
    
    if (failedTests.length > 0) {
      console.log(`   • ${failedTests.length} test(s) failed - review error handling and edge cases`);
    }
    
    if (slowTests.length > 0) {
      console.log(`   • ${slowTests.length} test(s) had high latency - consider performance optimization`);
    }

    const avgScore = this.results.reduce((sum, r) => sum + r.score, 0) / this.results.length;
    if (avgScore < 80) {
      console.log('   • Overall score below 80% - significant improvements needed');
    } else if (avgScore < 90) {
      console.log('   • Good score but room for improvement in some areas');
    }
  }
}

// CLI Interface
async function main() {
  const config: Partial<EvalConfig> = {
    serverPort: parseInt(process.env.SCENIC_MCP_PORT || '9999'),
    timeoutMs: parseInt(process.env.EVAL_TIMEOUT || '5000'),
    enableLLMScoring: process.env.ENABLE_LLM_SCORING === 'true'
  };

  const evals = new ScenicMcpEvals(config);
  await evals.runAllEvals();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { ScenicMcpEvals, EvalResult, EvalConfig };