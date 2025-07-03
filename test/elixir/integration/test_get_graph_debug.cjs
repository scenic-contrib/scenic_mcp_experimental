const net = require('net');

console.log('=== Scenic MCP get_scenic_graph Debug Test ===\n');

const client = new net.Socket();
const PORT = 9999;
const HOST = 'localhost';

// Test command
const testCommand = {
  action: "get_scenic_graph",
  detail_level: "summary"
};

console.log('Connecting to TCP server at', HOST + ':' + PORT);
console.log('Sending command:', JSON.stringify(testCommand, null, 2));

client.connect(PORT, HOST, () => {
  console.log('\n✅ Connected to server');
  
  // Send the command
  const jsonCommand = JSON.stringify(testCommand) + '\n';
  console.log('\nSending raw data:', jsonCommand.trim());
  client.write(jsonCommand);
});

client.on('data', (data) => {
  console.log('\n📥 Raw response received:');
  console.log(data.toString());
  
  try {
    const response = JSON.parse(data.toString());
    console.log('\n📋 Parsed response:');
    console.log(JSON.stringify(response, null, 2));
    
    if (response.status === 'ok') {
      console.log('\n✅ SUCCESS! Got visual feedback');
      console.log('\nDescription preview:');
      console.log(response.description.substring(0, 200) + '...');
      console.log('\nScript count:', response.script_count);
    } else if (response.error) {
      console.log('\n❌ ERROR:', response.error);
      if (response.viewport_state_keys) {
        console.log('Viewport state keys:', response.viewport_state_keys);
      }
      if (response.details) {
        console.log('Error details:', response.details);
      }
      if (response.stacktrace) {
        console.log('Stacktrace:', response.stacktrace);
      }
    }
  } catch (e) {
    console.log('\n❌ Failed to parse response:', e.message);
  }
  
  client.destroy();
});

client.on('error', (err) => {
  console.log('\n❌ Connection error:', err.message);
  console.log('\nMake sure:');
  console.log('1. Flamelex is running');
  console.log('2. The scenic_mcp server is started');
  console.log('3. Port 9999 is not blocked');
});

client.on('close', () => {
  console.log('\n🔌 Connection closed');
  console.log('\n=== Test Complete ===');
});
