# Testing Guide for Scenic MCP

This document describes the comprehensive testing strategy for the Scenic MCP server.

## 🧪 Test Suites Overview

### 1. **Elixir Unit & Integration Tests**
- **Location**: `test/scenic_mcp/`
- **Framework**: ExUnit
- **Coverage**: ScenicMcp.Server GenServer, TCP handling, command processing

### 2. **TypeScript Unit Tests**
- **Location**: `src/*.test.ts`
- **Framework**: Jest
- **Coverage**: MCP client logic, validation, error handling

### 3. **MCP Evaluations (Evals)**
- **Location**: `evals/`
- **Framework**: Custom evaluation suite
- **Coverage**: End-to-end MCP functionality, performance, reliability

## 🚀 Running Tests Locally

### Prerequisites
```bash
# Install system dependencies (macOS)
brew install glfw3 glew pkg-config

# Install system dependencies (Ubuntu)
sudo apt-get install build-essential libglfw3-dev libglew-dev pkg-config

# Install project dependencies
mix deps.get
npm install
```

### Individual Test Suites

```bash
# Elixir tests
mix test
mix test --cover                    # With coverage
mix coveralls.html                  # HTML coverage report

# TypeScript tests  
npm test
npm test -- --coverage             # With coverage
npm run test:watch                  # Watch mode

# MCP Evaluations
npm run test:evals

# All tests
npm run test:all
```

### Test Configuration

#### Elixir Test Environment
```elixir
# config/test.exs
config :scenic_mcp,
  tcp_port: 9998,  # Different port for tests
  test_mode: true
```

#### TypeScript Test Environment
```bash
# Environment variables for evals
export SCENIC_MCP_PORT=9999
export EVAL_TIMEOUT=10000
export ENABLE_LLM_SCORING=false
```

## 🔄 GitHub Actions CI/CD

### Pull Request Workflow
When you open a PR, the following tests run automatically:

1. **Multi-version Matrix Testing**
   - Elixir: 1.14, 1.15
   - OTP: 24, 25, 26
   - Node.js: 18, 20, 21

2. **Test Execution Order**
   ```
   ┌─ Elixir Tests ─────────────┐
   │  • Unit tests              │
   │  • Integration tests       │
   │  • Coverage reporting      │
   └────────────────────────────┘
            │
            ▼
   ┌─ TypeScript Tests ─────────┐
   │  • Jest unit tests         │
   │  • Build verification      │
   │  • Coverage reporting      │
   └────────────────────────────┘
            │
            ▼
   ┌─ MCP Evaluations ──────────┐
   │  • Server connectivity     │
   │  • Command processing      │
   │  • Error handling          │
   │  • Performance metrics     │
   └────────────────────────────┘
            │
            ▼
   ┌─ Integration Tests ────────┐
   │  • Full system testing     │
   │  • End-to-end scenarios    │
   └────────────────────────────┘
            │
            ▼
   ┌─ Security Scan ───────────┐
   │  • npm audit               │
   │  • Semgrep analysis        │
   │  • Secret detection        │
   └────────────────────────────┘
   ```

3. **PR Comments**
   - Automated test result summary
   - MCP evaluation scores
   - Performance metrics
   - Coverage reports

### Nightly Testing
Extended test suite runs every night at 2 AM UTC:

- **Cross-platform testing**: Multiple OS combinations
- **Performance benchmarks**: Latency and throughput analysis
- **Dependency auditing**: Security vulnerability scanning
- **Compatibility testing**: Latest Elixir/Node.js versions

### Release Workflow
Triggered on version tags (`v*`):

1. Full test suite execution
2. Build verification
3. Package publication (NPM + Hex)
4. GitHub release creation
5. Documentation updates

## 📊 MCP Evaluations Deep Dive

The MCP evaluation framework provides comprehensive testing beyond traditional unit tests:

### Evaluation Categories

#### 1. **Connectivity & Reliability** (25 points)
- TCP server startup and shutdown
- Connection handling
- Socket error recovery

#### 2. **Command Processing** (25 points)
- JSON parsing accuracy
- Command validation
- Response formatting

#### 3. **Tool Functionality** (30 points)
- `get_scenic_graph` command
- `send_keys` input simulation
- `send_mouse_move` and `send_mouse_click`
- `take_screenshot` capture

#### 4. **Error Handling** (10 points)
- Invalid JSON handling
- Unknown command responses
- Graceful failure modes

#### 5. **Performance** (10 points)
- Response latency (target: <500ms)
- Concurrent connection handling
- Memory usage patterns

### Scoring System

```
95-100: Excellent - Production ready
85-94:  Good - Minor improvements needed  
75-84:  Fair - Some issues to address
65-74:  Poor - Significant problems
<65:    Failing - Major fixes required
```

### Sample Evaluation Output

```
🖼️ Scenic MCP Server Evaluation Report
=========================================

📈 Overall Results:
   Tests Passed: 8/8 (100%)
   Average Score: 92/100
   Average Latency: 145ms

📋 Detailed Results:
1. ✅ Server Connectivity
   Score: 100/100
   Latency: 23ms
   Details: Successfully connected to TCP server

2. ✅ Command Parsing
   Score: 100/100
   Latency: 156ms
   Details: Commands parsed correctly

3. ✅ Error Handling
   Score: 100/100
   Latency: 89ms
   Details: Properly handles invalid JSON

4. ✅ Get Scenic Graph Tool
   Score: 85/100
   Latency: 203ms
   Details: Correctly handles missing viewport

5. ✅ Send Keys Tool
   Score: 85/100
   Latency: 134ms
   Details: Correctly handles key input without viewport

6. ✅ Mouse Interaction Tools
   Score: 85/100
   Latency: 167ms
   Details: Mouse tools handle missing viewport correctly

7. ✅ Screenshot Capture Tool
   Score: 85/100
   Latency: 198ms
   Details: Screenshot tool handles missing viewport correctly

8. ✅ Response Latency
   Score: 94/100
   Latency: 145ms
   Details: Average latency: 145ms across 10/10 successful requests

💡 Recommendations:
   • Good score but room for improvement in some areas
```

## 🛠️ Test Development Guidelines

### Writing Elixir Tests

```elixir
defmodule ScenicMcp.NewFeatureTest do
  use ExUnit.Case, async: false
  
  setup do
    # Setup test server
    {:ok, server_pid} = ScenicMcp.Server.start_link(port: 9998)
    on_exit(fn -> GenServer.stop(server_pid) end)
    %{server_pid: server_pid}
  end

  test "new feature works correctly", %{server_pid: server_pid} do
    # Test implementation
    assert something == expected
  end
end
```

### Writing TypeScript Tests

```typescript
describe('New Feature', () => {
  test('should handle input correctly', () => {
    const result = processInput('test input');
    expect(result).toEqual(expectedOutput);
  });
});
```

### Adding MCP Evaluations

```typescript
private async evalNewFeature(): Promise<void> {
  const testName = 'New Feature Evaluation';
  const startTime = Date.now();

  try {
    const command = { action: 'new_feature', param: 'test' };
    const response = await this.sendCommand(command);
    
    const passed = response && response.status === 'ok';
    const score = passed ? 100 : 0;

    this.results.push({
      testName,
      passed,
      score,
      details: passed ? 'Feature works correctly' : 'Feature failed',
      latency: Date.now() - startTime
    });
  } catch (error) {
    // Handle test error
  }
}
```

## 🔍 Debugging Test Failures

### Common Issues

#### 1. **Port Conflicts**
```bash
# Check if port is in use
lsof -i :9999

# Kill process using port
kill -9 <PID>
```

#### 2. **Missing System Dependencies**
```bash
# macOS
brew install glfw3 glew pkg-config

# Ubuntu
sudo apt-get install build-essential libglfw3-dev libglew-dev pkg-config
```

#### 3. **Timeout Issues**
```bash
# Increase timeout for slow systems
export EVAL_TIMEOUT=15000
```

### Test Logs

- **Elixir**: `mix test --trace`
- **TypeScript**: `npm test -- --verbose`
- **Evals**: Check server startup logs

## 📈 Performance Monitoring

### Metrics Tracked

- **Response Latency**: Per-command timing
- **Memory Usage**: Server memory consumption
- **Connection Count**: Concurrent connection limits
- **Error Rates**: Failed requests per time period

### Benchmarking

```bash
# Run performance benchmarks
export PERFORMANCE_MODE=true
npm run test:evals

# Generate performance report
node scripts/generate-perf-report.js
```

## 🤝 Contributing Test Cases

When adding new features:

1. **Write tests first** (TDD approach)
2. **Cover happy path and edge cases**
3. **Add MCP evaluation** for new tools
4. **Update this documentation**
5. **Verify CI/CD passes**

### Test Coverage Goals

- **Elixir**: >90% line coverage
- **TypeScript**: >85% line coverage  
- **MCP Evals**: >95% success rate
- **Integration**: All critical paths covered