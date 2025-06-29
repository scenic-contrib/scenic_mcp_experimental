const net = require('net');

function sendCommand(command) {
  return new Promise((resolve, reject) => {
    const client = new net.Socket();
    let response = '';

    client.connect(9999, 'localhost', () => {
      console.log('Connected to ScenicMCP server');
      client.write(JSON.stringify(command) + '\n');
    });

    client.on('data', (data) => {
      response += data.toString();
      if (response.includes('\n')) {
        client.destroy();
      }
    });

    client.on('close', () => {
      try {
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

async function testVisualFeedback() {
  try {
    console.log('\n=== Testing Visual Feedback System ===\n');

    // Step 1: Get initial state
    console.log('1. Getting initial visual state...');
    const initialState = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'summary'
    });
    console.log('Initial state:', JSON.stringify(initialState, null, 2));

    // Step 2: Send 'b' key to trigger blue box
    console.log('\n2. Sending "b" key to trigger blue box...');
    const keyResult = await sendCommand({
      action: 'send_keys',
      key: 'b'
    });
    console.log('Key send result:', keyResult);

    // Step 3: Wait a moment for the UI to update
    console.log('\n3. Waiting for UI to update...');
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Step 4: Get visual feedback again
    console.log('\n4. Getting visual feedback after blue box...');
    const afterState = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'summary'
    });
    
    console.log('\n=== Visual Feedback Result ===');
    if (afterState.description) {
      console.log(afterState.description);
      
      // Check if we can "see" the blue box
      const description = afterState.description.toLowerCase();
      if (description.includes('blue') || description.includes('rectangle') || description.includes('rect')) {
        console.log('\n✅ SUCCESS: Visual feedback detected UI changes!');
      } else {
        console.log('\n⚠️  WARNING: Visual feedback received but no blue box detected');
      }
    } else {
      console.log('\n❌ ERROR: No visual description received');
      console.log('Full response:', JSON.stringify(afterState, null, 2));
    }

    // Step 5: Try detailed view
    console.log('\n5. Getting detailed visual feedback...');
    const detailedState = await sendCommand({
      action: 'get_scenic_graph',
      detail_level: 'detailed'
    });
    
    if (detailedState.description) {
      console.log('\n=== Detailed View ===');
      console.log(detailedState.description);
    }

  } catch (error) {
    console.error('Test failed:', error);
  }
}

// Run the test
testVisualFeedback();
