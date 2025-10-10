
#!/bin/bash

echo "🛑 Stopping RCA dashboard..."

# Check if PID file exists
if [ -f flask.pid ]; then
  PID=$(cat flask.pid)

  # Check if process is running
  if ps -p $PID > /dev/null; then
    echo "🔧 Killing Flask process with PID $PID..."
    kill $PID
    sleep 1

    # Confirm termination
    if ps -p $PID > /dev/null; then
      echo "❌ Failed to terminate Flask process."
    else
      echo "✅ Flask process stopped."
      rm flask.pid
    fi
  else
    echo "⚠️ No running Flask process found for PID $PID. Cleaning up."
    rm flask.pid
  fi
else
  echo "⚠️ No flask.pid file found. Flask may not be running."
