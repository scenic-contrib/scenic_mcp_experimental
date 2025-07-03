#!/bin/bash

# Test script to boot app, test screenshot, and shutdown
echo "Starting screenshot test cycle..."

# Function to cleanup
cleanup() {
    echo "Cleaning up..."
    if [ ! -z "$APP_PID" ]; then
        echo "Killing app process $APP_PID"
        kill $APP_PID 2>/dev/null
        wait $APP_PID 2>/dev/null
    fi
    # Kill any processes using port 9999
    lsof -ti:9999 | xargs kill -9 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Kill any existing processes using port 9999
echo "Checking for existing processes on port 9999..."
lsof -ti:9999 | xargs kill -9 2>/dev/null || true
sleep 1

# Start the Quillex app (which will start its own scenic_mcp server)
echo "Starting Quillex app..."
cd /Users/luke/workbench/flx/quillex
MIX_ENV=dev elixir -S mix run --no-halt &
APP_PID=$!
echo "App started with PID: $APP_PID"

# Wait for app to fully initialize
echo "Waiting for app to initialize..."
sleep 10

# Test if TCP server is responding
echo "Testing TCP server connection..."
echo '{"action": "ping"}' | nc -w 5 localhost 9999 > /tmp/ping_response.txt 2>&1 &
NC_PID=$!
sleep 5
kill $NC_PID 2>/dev/null || true

if ! pgrep -f "port 9999" > /dev/null; then
    echo "No process listening on port 9999!"
    exit 1
fi

# Run the debug script in the app context
echo "Running debug script..."
cd /Users/luke/workbench/flx/quillex
elixir /Users/luke/workbench/flx/scenic_mcp/test_screenshot_debug.exs &
DEBUG_PID=$!
sleep 10
kill $DEBUG_PID 2>/dev/null || true

# Test screenshot via TCP
echo "Testing screenshot via TCP..."
echo '{"action": "take_screenshot", "filename": "test_screenshot.png", "format": "path"}' | nc -w 10 localhost 9999

echo "Test cycle complete!"