const net = require('net');

function sendCommand(command) {
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let response = '';

    client.connect(9999, 'localhost', () => {
      console.log('Connected to ScenicMCP server');
      const cmd = JSON.stringify(command) + '\n';
      console.log('Sending command:', cmd);
      client.write(cmd);
    });

    client.on('data', (data) => {
      response += data.toString();
      if (response.includes('\n')) {
        client.destroy();
      }
    });

    client.on('close', () => {
      try {
        console.log('Raw response:', response);
        const result = JSON.parse(response.trim());
        resolve(result);
      } catch (e) {
        reject(new Error(`Failed to parse response: ${response}`));
      }
    });

    client.on('error', (err) => {
      reject(err);
    });
  });
}

async function testScriptExtraction() {
  try {
    console.log('\n=== Testing Script Extraction ===\n');

    // First send 'b' key to ensure there's something to see
    console.log('1. Sending "b" key to create blue box...');
    await sendCommand({
      action: 'send_keys',
      key: 'b'
    });
    
    // Wait for UI update
    await new Promise(resolve => setTimeout(resolve, 500));

    // Now get the visual feedback with detailed level
    console.log('\n2. Getting detailed visual feedback...');
    const result = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'detailed'
    });

    console.log('\n=== Full Response ===');
    console.log(JSON.stringify(result, null, 2));

    // Check if we have any script data
    if (result.description) {
      console.log('\n=== Description Analysis ===');
      const desc = result.description.toLowerCase();
      
      console.log('Looking for visual elements...');
      console.log('- Contains "script":', desc.includes('script'));
      console.log('- Contains "element":', desc.includes('element'));
      console.log('- Contains "text":', desc.includes('text'));
      console.log('- Contains "rect":', desc.includes('rect'));
      console.log('- Contains "blue":', desc.includes('blue'));
      console.log('- Contains "compiled":', desc.includes('compiled'));
      console.log('- Contains "bytes":', desc.includes('bytes'));
    }

  } catch (error) {
    console.error('Test failed:', error);
  }
}

// Run the test
testScriptExtraction();
