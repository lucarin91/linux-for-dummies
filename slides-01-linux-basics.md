---
patat:
  wrap: true
  margins:
    left: 4
    right: 4
...

# Linux for QA — Session 1

## The Basics

lucarin91 — 2026-10-01

---

# Agenda

- What is Linux
- Distributions
- Shell & terminal
- Processes
- Filesystem structure
- Users & permissions
- systemd
- Networking basics
- Getting logs & files on/off a board

---

# Exercises — environment & setup

Try at your own pace, no pressure to finish everything.
Hints are at the bottom of each exercise don't peek before trying.

Requirements:
- Arduino UNO Q, connected via USB, accessed with `adb`
- Setup script from this repo: `scripts/setup-playground.sh`

```
adb push scripts/setup-playground.sh /sdcard/
adb shell
bash /sdcard/setup-playground.sh
cd ~/linux-practice
```

Creates `~/linux-practice`: a log file, a locked file, files of
varying size, a flaky script, and a background process.

---

# 1. What is Linux

A **kernel**, not a full OS — manages hardware, processes, memory, filesystems

What people call "Linux" (Ubuntu, Debian, Yocto image) is
- the kernel
- **GNU project** 
- defaults and configurations

. . .

Written by Linus Torvalds in 1991, now everywhere (phones, cars, servers, embedded devices, supercomputers).


Base philosophy: 
- *"Everything is a file"*: files, devices, kernel state — same `open`/`read`/`write`/`close` ops
- *Small tools that does one job*: `ls`, `cat`, `grep`, `awk`, `sed` — chain them with pipes to do complex tasks

. . .

```
uname -a   # kernel version, architecture
uname -r   # just the kernel version
```

---

# 2. Distributions

Distribution is a complete OS image: kernel + GNU + defaults/configs
with usually a **package manager**.

Each of which has its own philosophy, package format, and release cadence.

. . .

**Debian / Ubuntu**
Is a stable, general-purpose distro
- `apt` is the package manager
- `.deb` are the package files
- `dpkg` is the low-level package tool (used by `apt` under the hood)

. . .

**Yocto**
- Build framework, not an installable distro — creates a custom image
- Full control of what's on the device, cross-compiling, reproducible builds
- Image can be missing tools you'd assume exist — always check
- Usually no package manager

. . .

```
cat /etc/os-release
apt list --installed | wc -l
dpkg -l | grep <pkg>
```

---

# 2. Distributions — apt/dpkg quick answers

>- Update available? → `apt update` then `apt list --upgradable` finally `apt upgrade`
>- Where did this package come from? → `apt-cache policy <pkg>`
>- Which package owns this file? → `dpkg -S /path/to/file`
>- Which package gives me this command? → `apt-file search <command>`
>- Everything about a package? → `apt show <pkg>` / `dpkg -s <pkg>`

---

# Exercise — Package manager

>- Check if any installed package on your system has an update available
>- Pick any installed package and find out which repository it would come from
>- Find out which package owns a the file `/usr/bin/arduino-app-cli` you know exists 

---

# 3. Shell & terminal

**Terminal** is the program that display text and take inputs (iTerm2, GNOME Terminal...)
It was originally a physical device (VT100, serial console) but now is just a software emulator.

. . .

**Shell** command interpreter running inside it (`bash`, `zsh`, `fish`, `sh`)
Has its own syntax, built-in commands, and startup files (`~/.bashrc`, `~/.bash_profile`).
`sh` is the POSIX baseline — `bash`-only scripts can break under it

. . .

Any shell can run in any terminal — and a shell can run with no terminal (cron, CI)


```
echo $SHELL
ps -p $$
```

---

# 3. Shell shortcuts

**Terminal driver (any program)**
- `Ctrl+C` → SIGINT, interrupt
- `Ctrl+D` → EOF
- `Ctrl+Z` → SIGTSTP, suspend

. . .

**Readline (bash & friends)**
- `↑`/`↓` → step through history
- `Ctrl+R` → reverse search history
- `Tab` → autocomplete
- `Ctrl+A`/`Ctrl+E` → start/end of line

. . .

```
echo hello; ls -la; pwd      # then press ↑ a few times
# Ctrl+R, type "ls"
# type "ec", press Tab
```

---

# Exercise — Shell shortcuts

>- Run 4-5 different commands, then use `Ctrl+R` to find and
  re-run one of them without scrolling up
>- Type a long command (e.g. `echo this is a fairly long line`),
  then jump to the start/end with `Ctrl+A`/`Ctrl+E` instead of
  holding an arrow key

---

# 4. Processes — what they are

Every running program is a **process** with a PID and a PPID (parent process ID)

On Linux, a process is never created from nothing:
- **fork** clones an existing process
- **exec** replaces that copy with a different program

. . .

That's why every process has a parent. It's literally made by copying one
The parent can wait for the child to finish and collect its exit code, or it can ignore it. 

States: 
- `R` running
- `S` sleeping
- `T` stopped,
- `Z` zombie (finished, but its exit status hasn't been collected by the parent yet)

---

# 4. Processes — watching & controlling

>- `ps aux`, `top`/`htop` — list all / live view (CPU, mem, sortable)
>- `command &` runs in background, `jobs` lists background jobs
>- `fg`/`bg` bring a job to foreground / resume it in background
>- `Ctrl+Z` suspends the current foreground job (pauses, doesn't kill) into a running process, no restart needed

. . .

```
sleep 100 &
jobs
ps aux | grep sleep
kill %1

sleep 300 &
# Ctrl+Z to suspend it
bg      # resume it in the background
fg      # bring it back to the foreground
```

---

# 4. Processes — signals & priority

A **signal** is a lightweight, async way to interrupt a process
processes can choose to ignore, handle, or terminate on a signal.

. . .

`kill` doesn't just "kill" — it *sends a signal*, the process decides how to react
- `kill PID` → SIGTERM (15), can be caught, clean shutdown
- `kill -9 PID` → SIGKILL (9), immediate, no cleanup possible —
  the kernel tears it down directly, can't be caught or ignored
- `Ctrl+C` → SIGINT to foreground process

---

# Exercise — Processes

>- A background process was started for you by the setup script. Find it with `ps aux | grep sleep` (without looking at `.mystery_pid`)
>- Confirm the PID matches `.mystery_pid` (`cat .mystery_pid`)
>- Kill it with a plain `kill <PID>`, confirm it's gone
>- Bonus: `sleep 300 &`, suspend with `Ctrl+Z`, resume in background with `bg`, then bring to foreground with `fg`

---

# 8. stdin / stdout / stderr, pipes, exit codes

Each process has 3 default streams: **stdin (0)**, **stdout (1)**, **stderr (2)**

- Redirection: `> file`, `>> file`, `2> file`, `> out.log 2>&1`
- Pipes (`|`): stdout of one → stdin of next
- Exit codes: `0` = success, non-zero = failure — check with `echo $?`
- Chaning command execution `command && echo ok || echo failed`

. . .

```
ls /nope; echo $?
ls / ; echo $?
ls /etc | grep conf | wc -l
ls /nope > out.log 2>&1; cat out.log
```

---

# Exercise — Streams, pipes, exit codes

Using `app.log` from the playground:

>- Count how many `ERROR` lines it has, in one pipeline
>- Find lines that are *not* `INFO` (hint: `grep -v`)
>- Run `./flaky.sh` a few times and `echo $?` after each — notice the exit code changes
>- Redirect a run's stdout and stderr to two *separate* files (`out.log`/`err.log`) and check what landed in each
>- Chain it: `./flaky.sh && echo "succeeded" || echo "failed"` —
  run it a few times and watch it branch differently

---

# 5. Filesystem structure (FHS)

Single tree rooted at `/`, no drive letters.

| Path | Purpose |
|------|---------|
| `/bin`, `/usr/bin` | Executables |
| `/etc` | Config |
| `/home` | User homes |
| `/var` | Logs, caches |
| `/tmp` | Disposable |
| `/proc`, `/sys` | Virtual — live kernel/process info |
| `/dev` | Device files |

. . .

- Absolute (`/var/log/x`) vs relative (`../x`) paths
- Hidden files: start with `.`, shown by `ls -a`
- Symlinks: `ln -s target link`, `ls -l` shows `link -> target`

**Yocto**: `/` often read-only, overlay mounted for writable bits

. . .

```
ls -la /
df -h
du -sh /var/log
```

---

# 5. Freeing up disk space

>- Find the culprit first: `du -sh /* 2>/dev/null | sort -rh | head -10`
>- `apt clean` — drop cached `.deb` files
>- `apt autoremove` — drop orphaned dependencies
>- `journalctl --disk-usage` / `--vacuum-time=7d` — trim systemd logs
>- `docker system prune -a` — stopped containers/unused images

---

# 5. "Everything is a file," literally

Blink an LED with nothing but `echo`:

```
ls /sys/class/leds/
echo 1 > /sys/class/leds/<name>/brightness   # on
echo 0 > /sys/class/leds/<name>/brightness   # off
```

. . .

Same idea, reading instead of writing:

```
cat /proc/meminfo
cat /proc/cpuinfo
cat /proc/loadavg
```

`free`, `top`, `uptime` just read these files and format them.

---

# Exercise — Filesystem

Inside `~/linux-practice`:

>- Find every `.bin` file under the current directory (`find`)
>- Figure out which one is bigger without opening either (`du` or `ls -l`)
>- Create a symlink to `app.log` called `latest.log`, confirm with `ls -l` that it points where you expect, then delete the symlink and confirm `app.log` itself is untouched

---

# ☕ Fun break

```
sudo apt install -y cowsay fortune-mod sl figlet
fortune | cowsay        # a cow says a random quote
figlet "hello QA"       # giant ASCII-art text
sl                      # type this "by mistake" instead of ls
```

. . .

```
sudo apt install -y fastfetch
fastfetch                # distro/kernel/hardware, ASCII logo
```

. . .

A true classic, no install (needs internet + `telnet`):
```
telnet towel.blinkenlights.nl
```

. . .

Change your prompt on the fly — just `export`, no install, lasts
only for this shell (add to `.bashrc` to keep it):

```
PS1='\[\033[1;35m\]🐧[QA] \t@\h:\w\$ \[\033[0m\]'
```

---

# 6. Users & permissions

Every file defines an **owner** and a **group**, with permissions for **owner/group/other**.
Permissions are read/write/execute (r/w/x) for each of the three categories

- `ls -l` → `-rwxr-xr-x owner group` (`r`ead `w`rite e`x`ecute)
- `chmod 755 file` / `chmod +x file`, `chown user:group file`
- `sudo` — run one command as another user (root)

. . .

**Note**: a directory needs execute permission to be entered, and read permission to list its contents.

**Yocto**: often runs as root by default — check with `whoami`/`id`

```
whoami && id
touch test.sh && ls -l test.sh
chmod +x test.sh && ls -l test.sh
```

---

# Exercise — Users & permissions

>- Try to read `secret.txt` — it'll refuse. Figure out why (`ls -l secret.txt`) and fix it so you can `cat` it
>- Create a new script file, make it executable, and run it directly (`./yourscript.sh`) instead of via `bash yourscript.sh`

---

# 7. systemd

systemd is the modern Linux **init system** and service manager.
>- Its the process with PID 1, the first thing the kernel starts after booting.
>- It starts everything at boot, supervises services, and collects logs.

. . .

Declarative unit files define how to start/stop/restart a service, and what to do if it fails.
- `systemctl status|start|stop|restart <service>`
- `systemctl enable|disable <service>` — boot-time autostart
- `journalctl -u <service>` / `-f` to follow live

. . .

**arduno-app-cli** is a systemd service on the Arduino UNO Q used by app-lab.

```
systemctl list-units --type=service --state=running | head
systemctl status arduino-app-cli
journalctl -n 20
```

---

# Exercise — systemd

- List running services and pick one you recognize
- Check its status and look at its last few log lines with `journalctl -u <service> -n 20`

---


# 9. Networking basics

A machine has one IP address but usually runs many network services at once (a web server, an SSH daemon, a DNS resolver...)

Port number is simply how the kernel decides which one of those should receive a given packet.

. . .

Some useful commands to check connectivity and services:
- `ping host` — reachable at all (ICMP)
- `curl -v http://host:port/path` — HTTP request, status/headers
- `ss -tulpn` (or `netstat -tulpn`) — what's listening locally
- `nc -zv host port` — quick port-open check

. . .

```
ping -c 3 8.8.8.8
curl -v https://example.com
ss -tulpn | head
```

---

# Exercise — Networking

>- Ping something (`ping -c 3 1.1.1.1`)
>- Check what's listening on your own machine right now
>  (`ss -tulpn`) — see if you recognize any of it
>- `curl -v` a app-cli service at `http://localhost:8800/apps`

---

# 10. Getting logs & files on/off a board

**`scp` — SSH-reachable board**
```
scp file.txt user@board-ip:/path/        # to board
scp user@board-ip:/var/log/x.log ./      # from board
scp -r local-dir/ user@board-ip:/remote/
rsync -avz local-dir/ user@board-ip:/remote-dir/   # only changed files
```

**`adb` — Android-based target**
```
adb devices
adb push local_file /sdcard/path
adb pull /sdcard/path/file ./
adb shell
adb logcat -c && adb logcat > device.log
```

---

# Wrap-up

- Cheat sheet: `cheat-sheet.md` — hand out as take-home reference
- What was confusing or too fast?
