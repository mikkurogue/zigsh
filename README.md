# Zigsh - the worst shell known to man

This is yet another learning/passion project. Similar to [libarr](https://github.com/mikkurogue/libarr).
So don't think too much of this, nor use it as your actual shell at all (if anyone ever does this and daily drives this, I'll buy you a beer for sure).

# Configuration

Standard configuration lives in `XDG_HOME_PATH/.config/zigsh/config.toml`

this is the curently supported config:
```toml
sys_icon = "🦎" # pre prompt system icon, or whatever you want like a crocodile
user_color = "#ff5555" # user name color
host_color = "#5555ff" # hostname color
path_color = "#55ff55" # the path of the cwd/pwd color
prompt_icon = "❯" # what icon you want for the prompt itself
prompt_color = "#ffff55" # prompt icon color
show_toolchain = false # show the current language/ toolchain (not yet implemented)
```

### Supported OS
Currently, this was built and written on an Arch Linux system, using the 6.12.7-zen kernel. So I guess it supports Linux.

Now, I doubt it would necessarily break on Mac OS. Its possible it might work.

Windows, lol.
