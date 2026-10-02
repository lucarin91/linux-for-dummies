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
curl -fsSL https://pastebin.com/raw/mUVTLe5G | tr -d '\r' | bash
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

