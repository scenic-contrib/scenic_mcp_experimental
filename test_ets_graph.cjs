const net = require('net');

async function sendCommand(command) {
  return new Promise((resolve, reject) => {
    const client = net.createConnection({ port: 9999 }, () => {
      console.log('Connected to TCP server');
      client.write(JSON.stringify(command) + '\n');
    });

    let data = '';
    client.on('data', (chunk) => {
      data += chunk.toString();
      if (data.includes('\n')) {
        client.end();
        try {
          const response = JSON.parse(data.trim());
          resolve(response);
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      }
    });

    client.on('error', (err) => {
      reject(err);
    });

    setTimeout(() => {
      client.end();
      reject(new Error('Timeout waiting for response'));
    }, 5000);
  });
}

async function testEtsGraph() {
  console.log('Testing ETS-based graph retrieval...\n');

  try {
    // Test status first
    console.log('1. Checking server status...');
    const status = await sendCommand({ action: 'status' });
    console.log('Status:', JSON.stringify(status, null, 2));

    // Test get_scenic_graph with summary
    console.log('\n2. Getting scenic graph (summary)...');
    const summary = await sendCommand({ action: 'get_scenic_graph', detail_level: 'summary' });
    console.log('Summary response:', JSON.stringify(summary, null, 2));

    // Show the description in a readable format
    if (summary.description) {
      console.log('\n=== SCENIC GRAPH DESCRIPTION ===');
      console.log(summary.description);
      console.log('================================\n');
    }

    // Test get_scenic_graph with detailed
    console.log('\n3. Getting scenic graph (detailed)...');
    const detailed = await sendCommand({ action: 'get_scenic_graph', detail_level: 'detailed' });
    
    if (detailed.description) {
      console.log('\n=== DETAILED DESCRIPTION ===');
      console.log(detailed.description);
      console.log('============================\n');
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
}

testEtsGraph();
