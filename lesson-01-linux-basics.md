# Linux for QA — Session 1: The Basics (2h)

> Session 1 of a possible series — if this format works well, we can go deeper next week (networking, scripting, debugging tools, etc).

## Table of contents & timing (~130 min, trim if short on time)

| # | Topic | Time |
|---|-------|------|
| 1 | What is Linux | 10 min |
| 2 | Distributions | 10 min |
| 3 | Shell & terminal | 10 min |
| 4 | Processes | 15 min |
| 5 | Filesystem structure | 15 min |
| 6 | Users & permissions | 15 min |
| 7 | systemd | 15 min |
| 8 | stdin/stdout/stderr, pipes, exit codes | 20 min |
| 9 | Networking basics & useful commands | 10 min |
| 10 | Getting logs & files on/off a board | 10 min |

*Candidates for next session: SSH deep dive, package managers, text processing (grep/sed/awk), log analysis, scripting basics, cron/timers.*

Each section below ends with a **🔧 Try it** block — pause there and actually run the commands together rather than just reading them.

---

## 1. What is Linux

- Linux is a **kernel**, not a full OS by itself — it manages hardware, processes, memory, filesystems.
- What people call "a Linux" (Ubuntu, Debian, Yocto-built images...) is a distribution: kernel + userland tools + defaults built around it.
- Strictly speaking most of the everyday tools (shell, coreutils, compilers) come from the **GNU** project — hence "GNU/Linux" — the kernel itself is the small piece underneath that talks to hardware.
- Originally written by Linus Torvalds in 1991 as a hobby project; today it's open source (GPL-licensed) and runs on effectively everything: servers/cloud (most of the internet), Android phones, embedded/IoT devices, cars, and most of the world's supercomputers. Desktop is the one place it's a minority.
- Design philosophy worth internalizing: **"everything is a file"** — the slogan is a slight overstatement (worth being precise about, since it isn't literally true), but the real idea behind it holds up well: a huge amount of what the kernel manages — regular files, devices, kernel state, pipes — is exposed through the *same small set of operations* (`open`, `read`, `write`, `close`) instead of each needing its own bespoke API, and a lot of it (devices under `/dev`, kernel/process info under `/proc` and `/sys`) genuinely does show up as a path you can `ls`/`cat`. The honest exceptions: a network socket gets you those same operations through a file descriptor, but it has no path in the filesystem you could `ls` to find it; and configuring a network interface itself goes through entirely separate syscalls, not file I/O at all. "Almost everything looks like a file once you have a handle to it" is the more accurate version — still powerful, just not universal.
- The other half of the philosophy: "small tools that do one thing, combined together" — exactly why pipes, covered later, are so central.
- That's it for context — everything else in this session is really "how distributions built on this kernel behave." Keep this file-like-interface idea in mind — in the filesystem section we'll use it to blink an LED on a board with nothing but `echo`.

**🔧 Try it**
- `uname -a` — kernel version, architecture
- `uname -r` — just the kernel version

## 2. Distributions: Debian/Ubuntu & Yocto

Since this is what you'll actually touch day to day:

**Debian / Ubuntu**
- Ubuntu is derived from Debian — same package format and tooling, Ubuntu adds its own release cadence, defaults, and extra packages.
- Package manager: `apt` (front end) over `.deb` packages (`dpkg` is the lower-level tool underneath that actually installs/removes files and tracks what's on the system).
- `apt` resolves dependencies for you (installing package A that needs library B pulls B in automatically) — `dpkg` alone does not, which is why you rarely use `dpkg -i` directly except for a one-off local `.deb` file.
- Common commands: `apt update` (refresh package index — doesn't install anything itself), `apt upgrade` (actually upgrade installed packages), `apt install <pkg>`, `apt remove <pkg>` (keeps config files) vs `apt purge <pkg>` (removes those too), `dpkg -l | grep <pkg>` (is it installed).
- Ubuntu ships **LTS** releases (Long Term Support, 5 years of updates, even-numbered years) alongside regular 9-month releases — servers and CI images almost always standardize on an LTS.
- These are traditional, general-purpose distros: you install a base OS image, then add/remove packages on top as needed.

**A few `apt`/`dpkg` questions that come up constantly:**
- *"Is there an update for this package?"* — run `apt update` first (refreshes the index, doesn't install anything), then `apt list --upgradable` to see every package with a newer version available; `apt list --upgradable | grep <pkg>` to check just one. `apt-get upgrade -s` (`-s` = simulate) shows what a real upgrade *would* do without actually doing it.
- *"Where did this package come from / which repo will an update come from?"* — `apt-cache policy <pkg>` shows the installed version, the candidate (available) version, and the repo URL each came from — this is the go-to command when you need to know if a package is from the default Ubuntu repos, a PPA, or something else entirely. The full list of configured sources lives in `/etc/apt/sources.list` and `/etc/apt/sources.list.d/*.list`.
- *"Which package installed this file?"* — `dpkg -S /path/to/file` (works for files already on disk from an installed package).
- *"Which package would give me this command, if it isn't installed?"* — `apt-file search <command>` (needs `apt install apt-file` + `apt-file update` first); Ubuntu also auto-suggests this when you type an unknown command.
- *"Tell me everything about this package"* — `apt show <pkg>` (description, version, dependencies, size, source) vs `dpkg -s <pkg>` (installed status only, no need for network access).

**Yocto**
- Not a distro you install — it's a build framework that *creates* a custom embedded Linux image from source, including only what you ask for.
- Key vocabulary: a **layer** is a collection of related customizations (e.g. a BSP layer for a specific board); a **recipe** tells `BitBake` (the build engine) how to fetch, configure, and build one piece of software; **Poky** is the reference distribution that ties the default layers together.
- Why embedded projects choose it over "just Debian": full control over exactly what ends up on a resource-constrained device (flash/RAM budgets), reproducible builds, easier license compliance auditing, and it natively supports cross-compiling for a different CPU architecture than the build machine.
- The build also produces an **SDK** — a cross-toolchain — so application developers can compile software for the target without needing the full Yocto build environment.
- Practical consequence for QA: the resulting image can be missing tools you'd take for granted on Ubuntu — always check what's actually on the target rather than assuming.

**🔧 Try it**
- `cat /etc/os-release` — which distro and version am I actually on
- `apt list --installed | wc -l` (Debian/Ubuntu) — how many packages are installed
- Fun alternative: `sudo apt install -y fastfetch && fastfetch` — shows the same info with an ASCII distro logo (this replaced the once-popular `neofetch`, which was archived by its maintainer in 2024 and is no longer updated)

## 3. Shell & terminal

**Why the split exists**: "terminal" originally meant a physical device — a keyboard and screen (or literally a teletype printer) wired to a shared mainframe or minicomputer that many people used at once. The operating system needed *some* program reading what you typed and turning it into actions — that program is the shell. When computers stopped being physically wired to separate terminal hardware, "terminal emulators" were built purely to imitate that old behavior in software, which is why we still call a window "a terminal" even though there's no physical device left. The split has stuck around because it's genuinely useful, not just historical baggage: you can run any shell inside any terminal, run a shell with *no* terminal at all (cron jobs, CI pipelines), or attach many terminals to one machine at once (multiple SSH sessions) — decoupling "how you type" from "what interprets what you typed" is what makes all of that possible.

- **Terminal (emulator)**: the window/program that displays text and takes input (GNOME Terminal, iTerm2, Konsole, Windows Terminal).
- **Shell**: the program that interprets your commands, running inside the terminal (`bash`, `zsh`, `fish`, `sh`).
- Not the same thing — you can run any shell inside any terminal.
- `sh` is the POSIX baseline; scripts written for `bash`-isms may break under `sh` (common Docker gotcha: `#!/bin/sh` container, `bash`-only script fails).
- Check your shell: `echo $SHELL`, `ps -p $$`.
- **On Yocto targets**: often `ash` via BusyBox, not `bash` — a script that works on your dev machine can silently fail on the target.
- Startup files: `bash` reads `~/.bashrc` (interactive shells) and `~/.bash_profile`/`/etc/profile` (login shells) — this is where `PATH`, aliases, and prompt customizations live. If a command "works everywhere except in this script," it's very often because the script runs a non-interactive shell that never sourced `.bashrc`.
- **Aliases** are shortcuts for longer commands, defined in `.bashrc`: `alias ll='ls -la'`. Handy for QA: `alias tf='tail -f'`, `alias dc='docker compose'`.
- **Environment variables** carry configuration into processes: `$PATH` (where the shell looks for commands), `$HOME`, `$USER`. `export VAR=value` sets one for the current shell and anything it launches; without `export` it's local to the shell only.

### Shell shortcuts worth knowing (this saves the most time, day to day)

Two different layers are at play here, worth telling apart:

**Handled by the terminal driver itself (works in any program, not bash-specific)**
- **`Ctrl+C`** — sends SIGINT, interrupts the current foreground command.
- **`Ctrl+D`** — sends EOF (closes the current shell if the line is empty, or ends input for a command reading from the terminal).
- **`Ctrl+Z`** — sends SIGTSTP, suspends the current foreground job (covered next, in Processes).

**Handled by Readline, bash's line-editing layer (bash and Readline-based tools like `psql`/`python3`; other shells like zsh have their own similar-but-not-identical bindings)**
- **↑ / ↓ arrows** — step back/forward through command history one at a time.
- **`Ctrl+R`** — reverse search through history: start typing a fragment of a past command, it jumps to the most recent match; press `Ctrl+R` again to go further back, `Enter` to run it, `→`/`Esc` to edit it first instead of running immediately.
- **Tab** — autocomplete commands, paths, and (for many tools) flags; press twice to list all matches when there's more than one.
- **`history`** and **`!!`** — list past commands; `!!` re-runs the last one (e.g. `sudo !!` after forgetting `sudo`).
- **`Ctrl+A` / `Ctrl+E`** — jump to start / end of the current line (faster than holding an arrow key on a long command).

**🔧 Try it**
- Run `echo hello`, `ls -la`, `pwd` one after another, then press ↑ a few times to step back through them.
- Type `Ctrl+R`, then start typing `ls` — watch it jump to your last `ls` command.
- Type `ec` then press `Tab` — see it complete to `echo`.

## 4. Processes

**Why the model looks like this**: on Unix, a new process is never created from nothing — an existing process clones itself (`fork`), and that copy then replaces itself with a different program (`exec`). That's the historical reason every process *must* have a parent: it's a direct consequence of literally being created by copying one. The parent/child hierarchy exists so something is accountable for cleaning up after a process exits and collecting its exit status — which is exactly why zombies exist: a child that has finished, but whose parent hasn't yet collected that exit status. Signals exist because Unix needed a lightweight, asynchronous way to interrupt a running process from the outside without the overhead of real message-passing — a signal is essentially "a flag was raised, go handle it whenever you next check for it." That also explains why `SIGKILL` can't be caught or ignored: the kernel tears the process down directly instead of delivering a polite request the process would otherwise have to honor.

- Every running program is a **process** with a PID (process ID) and a PPID (parent process ID).
- `ps aux` — list all processes; `top` / `htop` — live view (CPU/mem usage, sortable, refreshes automatically).
- Parent/child relationships: shells spawn processes as children; killing a parent can kill (or orphan) its children. An orphaned process gets re-parented to `init`/PID 1.
- Process states you'll see in `ps`/`top`: `R` running, `S` sleeping (waiting, e.g. for I/O), `T` stopped/suspended, `Z` **zombie** (finished but its exit status hasn't been collected by the parent yet — usually harmless unless they pile up, which signals a parent that never reaps its children).
- Foreground vs background: `command &` runs in background, `jobs` lists background jobs, `fg`/`bg` bring one to foreground/resume it in background, `Ctrl+Z` suspends the current foreground job (pauses it, doesn't kill it) — this is the shortcut mentioned in the previous section.
- **Signals**: `kill` doesn't just "kill" — it *sends a signal*, and the process decides how to react.
  - `kill PID` = `SIGTERM` (15) — "please terminate," the process can catch this and clean up first.
  - `kill -9 PID` = `SIGKILL` (9) — the kernel kills it immediately, no cleanup possible — last resort, can leave things (lock files, half-written data) behind.
  - `kill -1 PID` = `SIGHUP` — traditionally "terminal hung up," many daemons interpret it as "reload your config."
  - `Ctrl+C` in a terminal sends `SIGINT` to the foreground process.
- **Priority**: `nice -n 10 command` starts a process with lower priority (higher niceness = more polite/lower priority, range -20 to 19); `renice` changes it for an already-running process. Rarely needed but explains why a background compile doesn't necessarily freeze everything else.
- `/proc/<PID>/` is a live window into a running process — `/proc/<PID>/status`, `/proc/<PID>/cwd`, `/proc/<PID>/environ` — useful when you need to know exactly what a running process is doing without restarting it.
- Why it matters for QA: a "hung" test runner is a process to inspect (`ps aux | grep`, `kill`), not just a black box to restart blindly — and a zombie pile-up or wrong signal choice can itself be the bug you're reporting.
- **On Yocto targets**: BusyBox's `ps` may not accept `aux` style flags — try plain `ps` or `ps -ef` if it complains.

**🔧 Try it**
- `sleep 100 &` then `jobs` — see it running in the background
- `ps aux | grep sleep` — find its PID
- `kill %1` (or `kill <PID>`) — stop it, then `jobs` again to confirm it's gone

## 5. Filesystem structure (FHS)

**Why it's standardized this way**: early Unix vendors each put files wherever they wanted, so knowing one Unix didn't mean you could find anything on another. The FHS (Filesystem Hierarchy Standard) exists purely to fix that — everyone agrees logs go in `/var/log`, configs go in `/etc`, and so on, so tools and admins can rely on it across distros. The single tree instead of drive letters isn't a style choice, either — it's a direct consequence of "everything is a file": if a USB stick, a network share, and a virtual `/proc` filesystem can all be grafted onto some directory of the *same* tree, then every tool that already knows how to read/write "a path" works on all of them automatically, with no special-cased logic per storage type. `/proc` and `/sys` being virtual (not real files on disk) is that same idea pushed further — the kernel exposes its own live internal state through the filesystem interface, because every single existing tool already understands "read a file," instead of every tool needing to learn a separate, bespoke API just to inspect the kernel.

Single tree rooted at `/`, no drive letters.

| Path | Purpose |
|------|---------|
| `/bin`, `/usr/bin` | Executables |
| `/etc` | System-wide configuration |
| `/home` | User home directories |
| `/var` | Variable data: logs (`/var/log`), caches, spool |
| `/tmp` | Temporary files, usually cleared on reboot |
| `/proc`, `/sys` | Virtual filesystems — live kernel/process info, not real files on disk |
| `/opt` | Optional/third-party software |
| `/dev` | Device files |
| `/root` | Home directory of the `root` user (not to be confused with `/`) |
| `/boot` | Kernel, bootloader files |
| `/media`, `/mnt` | Mount points for removable/temporary media |
| `/lib`, `/usr/lib` | Shared libraries |

Useful commands: `ls -la`, `cd`, `pwd`, `find /path -name "*.log"`, `df -h` (disk space), `du -sh dir/` (directory size).

- **Absolute vs relative paths**: `/var/log/syslog` (from root) vs `../log/syslog` (relative to where you are) — `.` is "here", `..` is "parent directory".
- **Hidden files**: anything starting with `.` (`.bashrc`, `.ssh/`) is hidden from a plain `ls`, not from `ls -a`/`ls -la` — "hidden" just means "not shown by default," not protected.
- **Symlinks** (`ln -s target linkname`) are pointers to another path — `ls -l` shows them as `link -> target`; deleting the link doesn't touch the target, but deleting/moving the target breaks the link (dangling symlink).
- **Wildcards/globbing**: `*` matches anything, `?` matches one character, `{a,b}` expands to both — e.g. `rm *.log`, `cp file.{txt,bak}`.
- **Mounting**: a mounted filesystem (a USB drive, a network share, an overlay) is attached at some directory in the single tree — `mount` with no arguments lists everything currently mounted; there's no separate drive letter, just another branch of `/`.

**Freeing up space, once `df -h` looks tight**
- Find what's actually eating the space first, don't guess: `du -sh /* 2>/dev/null | sort -rh | head -10` — sizes of everything at the top level, biggest first (a nice real-world use of the pipe/sort combo from earlier). Repeat inside whichever directory turns out to be the culprit to drill down further.
- `apt clean` — deletes cached `.deb` files in `/var/cache/apt/archives` (safe, they're just re-downloadable installers); `apt autoremove` — removes packages that were pulled in as dependencies but nothing needs anymore.
- **Logs are a very common silent offender**: `journalctl --disk-usage` shows how much space the systemd journal itself is using; `sudo journalctl --vacuum-time=7d` (keep a week) or `--vacuum-size=200M` (cap total size) trims it down without disabling logging.
- If you use Docker: `docker system prune` (add `-a` to also remove unused images, not just stopped containers/unused networks) — build/test images pile up fast and are individually easy to forget about.
- `/tmp` is meant to be disposable — usually cleared on reboot anyway (see the FHS table above), so it's a safe first place to check for accumulated junk (`du -sh /tmp`).

**On Yocto targets**: `/` is often **read-only**, with an overlay mounted for writable bits — a "read-only file system" error usually means you wrote outside that overlay, not a bug. Disk-space pruning above mostly doesn't apply here the same way: the image size is fixed at build time, so "running out of space" on a Yocto target is more often the writable overlay filling up (logs, test artifacts) than packages/caches to clean.

**🎉 "Everything is a file," literally: blink an LED with `echo`**

On a board like yours, an onboard LED is exposed under `/sys/class/leds/` — controlling hardware is *writing a value into a file*, nothing more exotic than that:
```
ls /sys/class/leds/                       # find the LED's name, e.g. "led0"
echo 1 > /sys/class/leds/<name>/brightness   # on
echo 0 > /sys/class/leds/<name>/brightness   # off
for i in 1 2 3; do echo 1 > /sys/class/leds/<name>/brightness; sleep 0.3; echo 0 > /sys/class/leds/<name>/brightness; sleep 0.3; done   # blink
```
If it's not directly under `/sys/class/leds/`, the same idea usually applies via `/sys/class/gpio/` (`export` a pin number, then `echo out > .../direction` and `echo 1|0 > .../value`). Either way: no special library, no driver API call from your shell — just a file, and a write to it, exactly the "everything is a file" idea from section 1. This is a nice one to physically demo in the room.

Same idea in the other direction — *reading* live stats instead of controlling hardware:
```
cat /proc/meminfo     # total/free/available memory, swap, buffers/cache — line by line
cat /proc/cpuinfo     # every CPU core, model, flags
cat /proc/loadavg     # the 3 load-average numbers `uptime` shows you
cat /proc/stat        # raw CPU time counters since boot
```
This is genuinely all `free`, `top`, and `uptime` are doing under the hood — they `cat` (or rather, read) one of these files, parse the text, and format it nicely. Nothing about memory or CPU usage requires a special monitoring API; it's the same "read a file" operation as everything else, which is exactly why you can build your own tiny version of `free` with `grep MemAvailable /proc/meminfo` and nothing else.

**🔧 Try it**
- `ls -la /` — browse the top-level tree
- `cd /var/log && ls -la` then `cd -` (jumps back to the previous directory)
- `df -h` and `du -sh /var/log`
- If you have a board handy: find and blink its LED as above
- `cat /proc/meminfo | head` and `free -h` side by side — same numbers, different presentation

**☕ 2-minute fun break** — halfway point. Unix people have always liked small silly tools alongside the serious ones:
```
sudo apt install -y cowsay fortune-mod sl
fortune | cowsay      # a cow says a random quote
sl                     # type this by "mistake" instead of ls
```
Back to it.

## 6. Users & permissions

**Why rwx / owner-group-other**: Unix was designed from day one as a *time-sharing* system — many people using the same physical machine at once — so its very first security problem was "don't let one user's files or processes get touched by another user's, unless explicitly allowed." Owner/group/other combined with read/write/execute is a deliberately minimal answer: three actors, three bits each, cheap enough for the kernel to check on *every single file access* without slowing the system down. Root exists as an explicit escape hatch on top of that model because someone has to be able to fix things when the permission system itself is in the way — administering a shared machine requires it.

- Every file has an **owner (user)**, a **group**, and permissions for **owner / group / others**.
- `ls -l` shows: `-rwxr-xr-x owner group`
  - `r` = read, `w` = write, `x` = execute (or "enter" for directories)
- Change with `chmod` (permissions) and `chown` (owner/group):
  - `chmod 755 script.sh` (owner: rwx, group/others: r-x)
  - `chmod +x script.sh` (just add execute)
  - `sudo chown user:group file`
- `sudo` = run a single command as another user (usually root), governed by `/etc/sudoers`.
- root (`uid 0`) bypasses permission checks — this is why "just chmod 777" is a bad habit, not a fix: it opens the file to every user on the system instead of fixing the actual owner/group mismatch.
- Groups let you share access without giving everyone root: `groups` (which groups am I in), `sudo usermod -aG groupname user` (add a user to a group — needs a fresh login/shell to take effect). Common one you'll hit: needing to be in the `docker` group to run Docker without `sudo`.
- Where this is tracked: `/etc/passwd` (user accounts), `/etc/group` (groups), `/etc/shadow` (password hashes, root-readable only) — you'll rarely edit these by hand, but it explains what `useradd`/`usermod`/`groupadd` are actually changing.
- **`umask`** controls the *default* permissions new files get (usually `022`, which is why new files land as `644`/`755` instead of `666`/`777`) — rarely need to change it, but explains why permissions differ across machines with a different default.
- Why it matters for QA: "permission denied" running a test script, or a test writing files another process can't read, is almost always this.
- **On Yocto targets**: often everything runs as `root` by default, so `whoami`/`id` is a quick check if that's not the case.

**🔧 Try it**
- `whoami` and `id` — who am I, what groups am I in
- `touch test.sh && ls -l test.sh` then `chmod +x test.sh && ls -l test.sh` — watch the permission bits change

## 7. systemd

**Why it replaced init scripts (and why it's controversial)**: the older approach (SysVinit) started services one at a time, in a fixed numbered order, using shell scripts that each had to reimplement their own "am I already running," "wait for the network," "log to the right place" logic — slow to boot, and easy to get subtly wrong in a dozen slightly different ways across services. systemd's idea was to make services *declarative*: a unit file states what a service needs and how to run it, and the init system itself figures out correct ordering, runs independent services in parallel, restarts anything that crashes, and centralizes logging — none of it reinvented per service. The trade-off is that systemd is a large, opinionated piece of software occupying what used to be a small, simple part of the system, which is exactly why some distros and embedded builds deliberately avoid it in favor of something smaller — if your team's image doesn't have `systemctl`, that's usually the reason.

- The **init system**: PID 1, starts everything else at boot, supervises services.
- Core commands:
  - `systemctl status <service>` — is it running, since when, recent log lines
  - `systemctl start|stop|restart <service>`
  - `systemctl enable|disable <service>` — start automatically at boot or not
  - `journalctl -u <service>` — full logs for that service
  - `journalctl -u <service> -f` — follow logs live (like `tail -f`)
- Why it matters for QA: when a test depends on a local service (DB, mock server), this is how you check "is it actually up" and "why did it die."
- **On Yocto targets**: `systemd` isn't a given — if `systemctl`/`journalctl` aren't there, check `/etc/init.d/` and `/var/log` instead.

**🔧 Try it**
- `systemctl list-units --type=service --state=running | head` — what's currently running
- `systemctl status cron` (or any service you spot above) — status + recent log lines in one view
- `journalctl -n 20` — last 20 log lines system-wide

## 8. stdin / stdout / stderr, pipes, exit codes

**Why 3 streams, and why pipes**: stdout and stderr are split so that a command's "real" output and its diagnostic chatter can be handled completely independently — you can pipe the actual data onward while errors still reach your screen (or redirect the errors away and keep watching the data), without one polluting the other. Pipes are a direct expression of the Unix philosophy from section 1 — "small tools that do one thing, combined" — rather than one large program that searches, counts, and formats in one step, Unix expects three small programs and a way to chain them: the pipe, which is just the kernel connecting one process's stdout file descriptor straight to another's stdin, no temporary file involved. Exit codes exist for the same underlying reason: once programs are chained/scripted together, *something* has to tell the next piece of automation whether the previous step actually succeeded, in a form simple enough that every program ever written, regardless of author or language, can produce consistently — a single integer.

- Every process has 3 default streams:
  - **stdin (0)** — input
  - **stdout (1)** — normal output
  - **stderr (2)** — errors/diagnostics, kept separate so you can filter it
- Redirection:
  - `command > file` — stdout to file (overwrite)
  - `command >> file` — stdout to file (append)
  - `command 2> file` — stderr to file
  - `command > out.log 2>&1` — both streams to the same file
- Pipes (`|`) chain commands: stdout of one becomes stdin of the next.
  - `ps aux | grep myapp`
  - `cat access.log | grep 500 | wc -l`
- **Exit codes**: every command returns a number on exit — `0` = success, non-zero = failure/error type.
  - Check with `echo $?` right after running a command.
  - Used constantly in scripts/CI: `command && echo ok || echo failed`.
- Why it matters for QA: this is the backbone of "did my test pass" in any CI pipeline — it's all exit codes and log redirection under the hood.

**🔧 Try it**
- `ls /nope; echo $?` then `ls /; echo $?` — compare exit codes for a failing vs succeeding command
- `ls /etc | grep conf | wc -l` — a 3-stage pipe
- `ls /nope > out.log 2>&1; cat out.log` — redirect both streams and inspect

## 9. Networking basics & useful commands

**Why ports, and why sockets behave like files**: a machine has one IP address but usually runs many network services at once (a web server, an SSH daemon, a DNS resolver...) — the port number is simply how the kernel decides which one of those should receive a given packet: same address, many separate mailboxes. A socket is a good example of the nuance from section 1: it's *not* a file you'd find by browsing the filesystem — you get one via a dedicated `socket()` call, not by opening a path — but once you have it, the same `read`/`write`/`close` operations that work on an ordinary file also work on it, which is why so many networking tools feel similar to file tools once you look underneath them.

Just enough to debug "why can't this thing connect":

- `ping host` — is it reachable at all (ICMP)
- `curl -v http://host:port/path` — make an HTTP request, see status code/headers
- `ss -tulpn` (or `netstat -tulpn`) — what's listening on which port, locally
- `nc -zv host port` — quick "is this port open" check
- A **socket** is just an endpoint (IP + port) for a network connection — you don't need deep internals, just know that "port in use" / "connection refused" / "connection timeout" map to different failure stages (nothing listening vs firewall vs host unreachable).
- **On Yocto targets**: minimal images may lack `curl`/`ss` entirely — "can't curl the board" can just mean it's not installed.

**🔧 Try it**
- `ping -c 3 8.8.8.8` — 3 pings then stop
- `curl -v https://example.com` — watch the connection + headers go by
- `ss -tulpn | head` — what's listening locally right now

## 10. Getting logs & files on/off a board

The recurring QA problem: "I have a log/test artifact on the board (or a test file that needs to go onto the board), how do I move it." In your setup this is almost always one of two tools: `scp` (network reachable, SSH available) or `adb` (Android-based target).

**`scp` — board reachable over the network with SSH**
- `scp file.txt user@board-ip:/path/` — copy a file *to* the board
- `scp user@board-ip:/var/log/thing.log ./` — copy a file *from* the board
- `scp -r local-dir/ user@board-ip:/remote-dir/` — whole directory, recursively
- If you need to run several commands rather than just move a file, `ssh user@board-ip` and work directly on the target instead of copying back and forth.
- `rsync -avz local-dir/ user@board-ip:/remote-dir/` is worth knowing about too: same idea as `scp -r` but only transfers what changed — much faster if you're re-pushing a test suite over and over with small edits.

**`adb` — Android-based target**
- `adb devices` — list connected devices/emulators (and confirm the connection actually works before anything else)
- `adb push local_file /sdcard/path` — copy a file *to* the device
- `adb pull /sdcard/path/file ./` — copy a file *from* the device
- `adb shell` — drop into an interactive shell on the device (same idea as `ssh` — for running several commands instead of one-off pushes/pulls)
- `adb logcat` — stream the device's system log live (the Android equivalent of `journalctl -f`); `adb logcat > device.log` to capture it to a file, `adb logcat -c` to clear the buffer before a test run so you only capture what's new
- `adb connect <ip>:5555` — switch from USB to a network connection, if the device supports ADB over Wi-Fi, so you're not tethered by cable

**🔧 Try it**
- `scp README.md user@<board-ip>:/tmp/` then `ssh user@<board-ip> cat /tmp/README.md`
- `adb devices` to confirm a device is visible, then `adb shell echo hello` as a minimal round-trip check.

---

📋 **Cheat sheet**: all the commands from this session, grouped by topic, are pulled out into [`cheat-sheet.md`](cheat-sheet.md) — hand that out separately as the take-home reference instead of this whole doc.

## Wrap-up

- Ask what was confusing or too fast — that shapes session 2.
- Possible next-session topics: SSH, package managers, grep/sed/awk for log digging, writing small bash scripts, cron & systemd timers.
