---
patat:
  wrap: true
  margins:
    left: 4
    right: 4
...

# Linux for QA — Session 2

## The Basics

lucarin91 — 2026-10-01

---

# Agenda

- Filesystem structure
- Users & permissions
- systemd
- Networking basics
- Getting logs & files on/off a board

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
echo 1 > /sys/class/leds/unoq\:user-green1/brightness   # on
echo 0 > /sys/class/leds/unoq\:user-green1/brightness   # off
```

*Note*: on unoq we conviniently link led name in `/dev/leds/builtin/` and `/dev/leds/mediacarrier/`

```
echo 1 > /dev/leds/builtin/led1_g/brightness
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
