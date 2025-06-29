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

async function testViewportState() {
  console.log('Testing viewport state access...\n');

  try {
    // First check status to see what info we get
    console.log('1. Checking server status...');
    const statusResponse = await sendCommand({
      action: 'status'
    });
    console.log('Status:', JSON.stringify(statusResponse, null, 2));
    
    // Send a 'b' key to trigger visual change
    console.log('\n2. Sending "b" key to trigger blue box...');
    const keyResponse = await sendCommand({
      action: 'send_keys',
      key: 'b'
    });
    console.log('Key response:', keyResponse);
    
    // Wait for the scene to update
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Try to get the scenic graph with summary level
    console.log('\n3. Getting scenic graph (summary)...');
    const summaryResponse = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'summary'
    });
    
    console.log('\n=== SUMMARY RESPONSE ===');
    console.log(JSON.stringify(summaryResponse, null, 2));
    
    if (summaryResponse.description) {
      console.log('\n=== DESCRIPTION ===');
      console.log(summaryResponse.description);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

testViewportState();
