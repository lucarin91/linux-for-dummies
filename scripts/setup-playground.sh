#!/usr/bin/env bash
# Sets up a self-contained practice sandbox for the take-home exercises.
# Safe to re-run — it only touches its own playground directory.
set -euo pipefail

PLAYGROUND="${1:-$HOME/linux-practice}"
mkdir -p "$PLAYGROUND/reports"
cd "$PLAYGROUND"

# Exercise: pipes/grep/exit codes — a log with mixed severity lines
cat > app.log <<'EOF'
2026-01-10 09:12:01 INFO  startup complete
2026-01-10 09:12:03 INFO  listening on port 8080
2026-01-10 09:14:22 WARN  slow response from db (450ms)
2026-01-10 09:15:01 ERROR failed to connect to cache: timeout
2026-01-10 09:15:02 INFO  retrying connection
2026-01-10 09:15:05 ERROR failed to connect to cache: timeout
2026-01-10 09:15:10 INFO  connection restored
2026-01-10 09:20:44 ERROR unhandled exception in worker 3
2026-01-10 09:21:00 INFO  worker 3 restarted
EOF

# Exercise: permissions — this file exists but can't be read yet
echo "if you can read this, you fixed it" > secret.txt
chmod 000 secret.txt

# Exercise: filesystem — files of different sizes to find/measure
head -c 1000 /dev/urandom > reports/small.bin
head -c 500000 /dev/urandom > reports/medium.bin
touch reports/notes.txt reports/notes.txt.bak

# Exercise: exit codes — a script that succeeds or fails at random
cat > flaky.sh <<'EOF'
#!/usr/bin/env bash
if (( RANDOM % 2 )); then
  echo "ok"
  exit 0
else
  echo "boom" >&2
  exit 1
fi
EOF
chmod +x flaky.sh

# Exercise: processes — a background "mystery" process to track down
nohup sleep 900 >/dev/null 2>&1 &
disown
echo $! > .mystery_pid

echo "Playground ready at: $PLAYGROUND"
echo "A background process was started for the processes exercise — don't peek at .mystery_pid until told to check your answer."
