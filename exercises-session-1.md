# Take-home exercises — Session 1

Try these on your own, at your own pace. No pressure to finish everything — pick whatever section felt least solid in the live session. Solutions/hints are at the bottom of each exercise if you get stuck, don't peek before trying.

## Getting a Linux environment

Use your Arduino UNO Q — it runs actual Debian Linux on its Qualcomm side (a separate STM32 handles the real-time/Arduino-core side), so everything in this session applies directly, no VM or emulation needed. Prefer `ssh` (see its docs for the default connection setup) — it gives you a real login as yourself, with your normal home directory and environment. `adb shell` also gets you a shell on the same Linux, but it isn't a full login the same way — for these exercises the difference won't matter much, but if something behaves oddly (a missing env var, wrong working directory), that's usually why.

## Setup

Copy `scripts/setup-playground.sh` from this repo onto the board — `scp setup-playground.sh user@<board-ip>:~/` or `adb push setup-playground.sh /sdcard/` (same as section 10 of the lesson), then run it once from your shell on the board:

```
bash setup-playground.sh
cd ~/linux-practice
```

(if you pushed it via `adb push`, adjust the path in `bash ...` to wherever you pushed it, e.g. `bash /sdcard/setup-playground.sh`)

It creates a `~/linux-practice` folder with a log file, a locked file, some files of varying size, a flaky script, and a background process — used by the exercises below. Re-running it is safe.

---

## 1. Shell shortcuts

- Run 4-5 different commands, then use `Ctrl+R` to find and re-run one of them without scrolling up.
- Type a long command (e.g. `echo this is a fairly long line of text`), then practice jumping to the start/end with `Ctrl+A`/`Ctrl+E` instead of holding an arrow key.

## 2. Filesystem

Inside `~/linux-practice`:
- Find every `.bin` file under the current directory (`find`).
- Figure out which one is bigger without opening either (`du` or `ls -l`).
- Create a symlink to `app.log` called `latest.log`, confirm with `ls -l` that it points where you expect, then delete the symlink and confirm `app.log` itself is untouched.

## 3. Users & permissions

- Try to read `secret.txt` — it'll refuse. Figure out why (`ls -l secret.txt`) and fix it so you can `cat` it.
- Create a new script file, make it executable, and run it directly (`./yourscript.sh`) instead of via `bash yourscript.sh`.

<details><summary>Hint</summary>

`chmod 000 secret.txt` means nobody (not even the owner) has any permission — `chmod u+r secret.txt` (or `chmod 644 secret.txt`) fixes it for yourself.
</details>

## 4. Processes

- A background process was started for you by the setup script. Find it with `ps aux | grep sleep` (without looking at `.mystery_pid`).
- Confirm the PID you found matches `.mystery_pid` (`cat .mystery_pid`).
- Kill it with a plain `kill <PID>`, confirm it's gone with `ps aux | grep sleep` again.
- Bonus: start `sleep 300 &`, suspend it with `Ctrl+Z`, then resume it in the background with `bg`, and finally bring it to the foreground with `fg`.

## 5. Streams, pipes, exit codes

Using `app.log` from the playground:
- Count how many `ERROR` lines it has, in one pipeline.
- Find lines that are *not* `INFO` (hint: `grep -v`).
- Run `./flaky.sh` a few times and `echo $?` after each — notice the exit code changes.
- Redirect a run's stdout and stderr to two *separate* files (`out.log`/`err.log`) and check what landed in each.
- Chain it: `./flaky.sh && echo "succeeded" || echo "failed"` — run it a few times and watch it branch differently.

## 6. systemd

- List running services and pick one you recognize.
- Check its status and look at its last few log lines with `journalctl -u <service> -n 20`.

## 7. Networking

- Ping something (`ping -c 3 1.1.1.1`).
- `curl -v` a website and find the HTTP status code in the output.
- Check what's listening on your own machine right now (`ss -tulpn`) — see if you recognize any of it.

## 8. Package manager

- Check if any installed package on your system has an update available.
- Pick any installed package and find out which repository it would come from.
- Find out which package owns a file you know exists, e.g. `dpkg -S $(which ls)`.

---

## Bonus: just for fun

None of this is on the exam, but it's a nice way to end a Linux session — classic terminal toys that exist purely because Unix people like to have fun with small tools:

```
sudo apt install -y cowsay fortune-mod sl figlet
fortune | cowsay        # a cow says a random quote
figlet "hello QA"       # giant ASCII-art text
sl                       # type this instead of `ls` by mistake... on purpose this time
```

```
sudo apt install -y fastfetch
fastfetch                # your distro/kernel/hardware, shown off with an ASCII logo
```
(This is the actively-maintained successor to the once-popular `neofetch`, which its maintainer archived in 2024.)

And a true classic, no install required (needs internet + `telnet`):
```
telnet towel.blinkenlights.nl
```
