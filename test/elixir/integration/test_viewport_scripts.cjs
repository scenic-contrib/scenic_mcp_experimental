const net = require('net');

function sendCommand(command) {
  return new Promise((resolve, reject) => {
    const client = net.createConnection({ port: 9999 }, () => {
      console.log('Connected to TCP server');
      client.write(JSON.stringify(command) + '\n');
    });

    let data = '';
    client.on('data', (chunk) => {
      data += chunk.toString();
      if (data.includes('\n')) {
        try {
          const response = JSON.parse(data.trim());
          resolve(response);
        } catch (e) {
          reject(e);
        }
        client.end();
      }
    });

    client.on('error', reject);
  });
}

async function testViewportScripts() {
  console.log('Testing viewport script retrieval...\n');

  try {
    // First, send a 'b' key to trigger the blue box
    console.log('1. Sending "b" key to trigger blue box...');
    const keyResponse = await sendCommand({
      action: 'send_keys',
      key: 'b'
    });
    console.log('Key response:', keyResponse);
    
    // Wait a bit for the scene to update
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Now get the scenic graph
    console.log('\n2. Getting scenic graph...');
    const graphResponse = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'detailed'
    });
    
    console.log('\n=== SCENIC GRAPH RESPONSE ===');
    console.log(JSON.stringify(graphResponse, null, 2));
    
    if (graphResponse.description) {
      console.log('\n=== DESCRIPTION ===');
      console.log(graphResponse.description);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

testViewportScripts();
