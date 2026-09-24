# dwm-install

Post-install scripts for my dwm environment on Arch Linux and Debian.

Installs programs, builds my source repositories, deploys dotfiles,
and configures the desktop. The base OS installation is kept separate.

## Installation

Run as your normal user, **not as root**.

### Arch Linux

```sh
sudo pacman -S --needed curl
curl -fLo "$HOME/dwm-install.sh" \
    https://raw.githubusercontent.com/rabbi-lion/dwm-install/master/arch/dwm-install.sh
chmod +x "$HOME/dwm-install.sh"
"$HOME/dwm-install.sh"
```

### Debian

```sh
sudo apt-get update
sudo apt-get install -y curl
curl -fLo "$HOME/dwm-install.sh" \
    https://raw.githubusercontent.com/rabbi-lion/dwm-install/master/debian/dwm-install.sh
chmod +x "$HOME/dwm-install.sh"
"$HOME/dwm-install.sh"
```

Check syntax before running:

```sh
bash -n "$HOME/dwm-install.sh" && echo "Syntax OK"
```

Keep a log:

```sh
"$HOME/dwm-install.sh" 2>&1 | tee "$HOME/dwm-install.log"
```

The installer removes its downloaded copy after a successful install.

## Requirements

A working base install of Arch or Debian, with:

- networking and an internet connection
- a normal user account with `sudo`
- a working bootloader

Partitioning, filesystems, bootloader setup, and user creation are
not handled by these scripts.

## What it installs

- dwm, st, dmenu, dwmblocks
- nsxiv, Thunar, mpv, Neovim
- Firefox, Thunderbird
- PipeWire, WirePlumber

Exact package lists live in the installer scripts.

## Source repositories

Custom builds are installed from:

```
https://github.com/rabbi-lion/dwm
https://github.com/rabbi-lion/st
https://github.com/rabbi-lion/dwmblocks
https://github.com/rabbi-lion/nsxiv
```

`dmenu` is stock, built from suckless.

Sources are cloned under `~/src/`. Dotfiles are cloned temporarily
from `https://github.com/rabbi-lion/dotfiles` during installation.

## dwm

Includes:

- vanity gaps
- scratchpads
- swallowing
- sticky windows
- centered floating windows
- stack rotation
- clickable dwmblocks
- dwmblocks signaling

## st

Includes scrollback, mouse scrolling, and helper bindings:

```
Alt+l       open URL
Alt+y       copy URL
Alt+o       copy terminal output
Shift+PgUp  scroll up
Shift+PgDn  scroll down
```

## Status bar

`dwmblocks` provides the status bar. Default blocks:

```
internet | brightness | volume | battery | clock
```

Status scripts live in `~/.local/bin/statusbar/`.

## nsxiv

Default image viewer. Compiled from source
(`https://github.com/rabbi-lion/nsxiv`), not installed from distro
repositories.

Includes directory-aware image opening, Thunar integration, common
image MIME associations, Trash support, and nsxiv key handling.

File-manager helper: `~/.local/bin/nsxiv-rifle`. Stock scaling is
preserved.

## Desktop configuration

Dotfiles configure bash, dunst, Firefox, GTK, mpv, Neovim, nsxiv,
Redshift, Thunderbird, Thunar, Xresources, yt-dlp, and Zathura.

The graphical session is started through `.xinitrc`, which launches:

```
Xresources
Redshift
wallpaper
dunst
dwmblocks
dwm
```

Caps Lock and Escape are swapped for the X session.

## Audio

PipeWire and WirePlumber, with PulseAudio and JACK compatibility.
Device handling uses `wpctl`.

## Firefox and Thunderbird

Both receive system policies from the dotfiles repo. The policies
set `widget.use-xdg-desktop-portal.file-picker = 0` so both use
native file pickers instead of the XDG portal picker.

Firefox also gets privacy and interface preferences, plus:

- uBlock Origin
- Dark Reader
- Enhancer for YouTube
- I Still Don't Care About Cookies

On Debian, policies install to:

- Firefox: `/etc/firefox/policies/policies.json`
- Thunderbird: `/usr/lib/thunderbird/distribution/policies.json`

## Wallpaper

Default: `space.jpg`, installed to `~/Pictures/Wallpapers/`.

## Redshift and keyboard

The installer prompts for latitude and longitude. Default
temperatures:

```
Day:   6500 K
Night: 4500 K
```

US keyboard assumed by default; other console and X11 layouts can
be selected during install.

## NVIDIA

Optional. If NVIDIA hardware is detected, the installer offers to
install the appropriate driver packages for the distro.

## Notes

Intended for fresh or minimal systems. Existing matching config
files may be overwritten. Machine-specific and Polkit configuration
are intentionally kept out of the public installer.

## License

Made by rabbi-lion. Licensed under the GNU GPL v3. See `LICENSE`.

Programs built or installed by these scripts retain their own
licenses.
