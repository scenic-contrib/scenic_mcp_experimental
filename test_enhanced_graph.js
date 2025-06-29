#!/usr/bin/env node

const net = require('net');

async function sendCommand(command) {
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let responseData = '';
    
    client.connect(9999, 'localhost', () => {
      const message = typeof command === 'string' ? command : JSON.stringify(command);
      client.write(message + '\n');
    });
    
    client.on('data', (data) => {
      responseData += data.toString();
      if (responseData.includes('\n')) {
        client.destroy();
        resolve(responseData.trim());
      }
    });
    
    client.on('error', (err) => {
      reject(err);
    });
  });
}

async function testEnhancedGraph() {
  console.log('Testing Enhanced Graph Introspection...\n');
  
  try {
    // Test hello
    console.log('1. Testing connection...');
    const helloResponse = await sendCommand('hello');
    console.log('Response:', JSON.parse(helloResponse).message);
    
    // Test summary graph
    console.log('\n2. Testing summary graph introspection...');
    const summaryResponse = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'summary'
    });
    const summaryData = JSON.parse(summaryResponse);
    console.log('Summary Response:');
    console.log(summaryData.description);
    
    // Test detailed graph
    console.log('\n3. Testing detailed graph introspection...');
    const detailedResponse = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'detailed'
    });
    const detailedData = JSON.parse(detailedResponse);
    console.log('Detailed Response:');
    console.log(detailedData.description);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// Run the test
testEnhancedGraph();
