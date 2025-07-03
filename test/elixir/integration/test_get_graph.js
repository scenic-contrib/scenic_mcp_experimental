#!/usr/bin/env node

// Test script for the get_scenic_graph MCP tool

async function testGetScenicGraph() {
  console.log('Testing get_scenic_graph MCP tool...\n');

  try {
    // First, check connection
    console.log('1. Checking Scenic connection...');
    const connectResult = await useMcpTool('scenic', 'connect_scenic', {});
    console.log('Connection result:', connectResult);
    console.log('');

    // Test summary view
    console.log('2. Testing get_scenic_graph with summary view...');
    const summaryResult = await useMcpTool('scenic', 'get_scenic_graph', {
      detail_level: 'summary'
    });
    console.log('Summary result:');
    console.log(summaryResult);
    console.log('');

    // Test detailed view
    console.log('3. Testing get_scenic_graph with detailed view...');
    const detailedResult = await useMcpTool('scenic', 'get_scenic_graph', {
      detail_level: 'detailed'
    });
    console.log('Detailed result:');
    console.log(detailedResult);
    console.log('');

    // Test default (no detail_level specified)
    console.log('4. Testing get_scenic_graph with default settings...');
    const defaultResult = await useMcpTool('scenic', 'get_scenic_graph', {});
    console.log('Default result:');
    console.log(defaultResult);

  } catch (error) {
    console.error('Error:', error);
  }
}

// Helper function to use MCP tools
async function useMcpTool(serverName, toolName, args) {
  // This is a placeholder - in real usage, this would connect to the MCP server
  console.log(`[MCP] Calling ${serverName}.${toolName} with args:`, args);
  
  // For testing purposes, we'll make a direct TCP connection
  const net = require('net');
  
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let responseData = '';
    
    client.connect(9999, 'localhost', () => {
      const command = {
        action: toolName.replace('_', '_').replace('connect_scenic', 'status').replace('get_scenic_graph', 'get_scenic_graph'),
        ...args
      };
      
      if (toolName === 'connect_scenic') {
        client.write('hello\n');
      } else {
        client.write(JSON.stringify(command) + '\n');
      }
    });
    
    client.on('data', (data) => {
      responseData += data.toString();
      if (responseData.includes('\n')) {
        client.destroy();
        try {
          const response = JSON.parse(responseData.trim());
          resolve(response);
        } catch (e) {
          resolve(responseData.trim());
        }
      }
    });
    
    client.on('error', (err) => {
      reject(err);
    });
    
    setTimeout(() => {
      client.destroy();
      reject(new Error('Connection timeout'));
    }, 5000);
  });
}

// Run the test
testGetScenicGraph().catch(console.error);
