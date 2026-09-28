# Cheat sheet — most useful commands

A quick-reference summary of [Session 1](lesson-01-linux-basics.md), grouped by topic — good as a printed/pinned reference afterward.

**System info**
```
uname -a                 # kernel + architecture
cat /etc/os-release      # distro name/version
```

**Packages (Debian/Ubuntu)**
```
apt update                       # refresh package index (no installs)
apt list --upgradable            # what has updates available
apt-cache policy <pkg>           # installed vs candidate version + source repo
apt install / remove / purge <pkg>
dpkg -l | grep <pkg>             # is it installed
dpkg -S /path/to/file            # which package owns this file
apt show <pkg>                   # full package info
```

**Shell**
```
history            # list past commands
Ctrl+R             # reverse search history
!!                 # re-run last command
!$                 # last argument of previous command
Tab                # autocomplete
```

**Filesystem**
```
ls -la              # list all, long format
cd -                # jump to previous directory
find /path -name "*.log"
df -h               # disk space per filesystem
du -sh dir/         # size of a directory
```

**Freeing up disk space**
```
du -sh /* 2>/dev/null | sort -rh | head -10   # biggest things at top level
apt clean                                      # clear cached .deb files
apt autoremove                                 # remove orphaned dependencies
journalctl --disk-usage                        # how big is the systemd journal
journalctl --vacuum-time=7d                    # trim journal to last 7 days
docker system prune -a                         # unused containers/images (if using Docker)
```

**Users & permissions**
```
whoami / id         # who am I, what groups
ls -l               # see owner/group/permissions
chmod +x file       # add execute
chmod 755 file      # set exact permissions
chown user:group file
sudo <command>      # run as root
```

**Processes**
```
ps aux              # list all processes
top / htop          # live view
command &           # run in background
jobs / fg / bg       # manage background jobs
kill PID             # SIGTERM (ask nicely)
kill -9 PID          # SIGKILL (force)
```

**systemd**
```
systemctl status <service>
systemctl start|stop|restart <service>
systemctl enable|disable <service>
journalctl -u <service> -f    # follow logs live
journalctl -n 20              # last 20 lines, system-wide
```

**Streams, pipes, exit codes**
```
command > file 2>&1     # redirect both stdout+stderr to file
command1 | command2     # pipe output into next command
echo $?                  # exit code of last command
cmd && ok || failed      # branch on success/failure
```

**Networking**
```
ping -c 3 host
curl -v http://host:port/path
ss -tulpn                # what's listening locally
nc -zv host port         # is this port open
```

**Getting files on/off a board**
```
scp file user@host:/path/         # copy to (SSH)
scp user@host:/path/file ./       # copy from (SSH)
ssh user@host                     # work directly on the target
adb devices                       # list connected devices
adb push local_file /sdcard/path  # copy to (Android)
adb pull /sdcard/path/file ./     # copy from (Android)
adb shell                         # interactive shell on device
adb logcat -c && adb logcat > device.log   # clear then capture logs
```
