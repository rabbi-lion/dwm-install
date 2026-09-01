# dwm-install

Post-install scripts for setting up my dwm environment on Arch Linux and Debian.

The scripts install the required programs, build my custom source repositories, deploy my dotfiles and configure the desktop environment.

The base operating system installation is intentionally kept separate.

## Installation

Run the installer as your normal user, **not as root**.

### Arch Linux

```sh
sudo pacman -S --needed curl

curl -fLo "$HOME/dwm-install.sh" https://raw.githubusercontent.com/rabbi-lion/dwm-install/master/arch/dwm-install.sh

chmod +x "$HOME/dwm-install.sh"
"$HOME/dwm-install.sh"
```

### Debian

```sh
sudo apt-get update
sudo apt-get install -y curl

curl -fLo "$HOME/dwm-install.sh" https://raw.githubusercontent.com/rabbi-lion/dwm-install/master/debian/dwm-install.sh

chmod +x "$HOME/dwm-install.sh"
"$HOME/dwm-install.sh"
```

To check the script before running it:

```sh
bash -n "$HOME/dwm-install.sh" && echo "Syntax OK"
```

To keep an installation log:

```sh
"$HOME/dwm-install.sh" 2>&1 | tee "$HOME/dwm-install.log"
```

The installer removes its downloaded copy after a successful installation.

## Preparation

A working base installation of Arch Linux or Debian is required.

Before running the installer, the system should already have:

- networking
- a normal user account
- `sudo` access
- a working bootloader
- an internet connection

Partitioning, filesystems, bootloader installation, user creation and other base-installation tasks are not handled by these scripts.

## What it installs

The environment is based around:

- dwm
- st
- dmenu
- dwmblocks
- nsxiv
- Thunar
- mpv
- Neovim
- Firefox
- Thunderbird
- PipeWire
- WirePlumber

The exact package lists are kept in the installer scripts.

## Source repositories

My custom builds are installed from:

```text
https://github.com/rabbi-lion/dwm
https://github.com/rabbi-lion/st
https://github.com/rabbi-lion/dwmblocks
https://github.com/rabbi-lion/nsxiv
```

`dmenu` is kept stock and built directly from suckless.

Source repositories are installed under:

```text
~/src/
```

The dotfiles repository is cloned temporarily during installation:

```text
https://github.com/rabbi-lion/dotfiles
```

## dwm

My dwm build includes:

- vanity gaps
- scratchpads
- swallowing
- sticky windows
- desktop toggle
- centered floating windows
- stack rotation
- clickable dwmblocks
- dwmblocks signaling

## st

My st build includes scrollback, mouse scrolling and helper bindings for URLs and terminal output.

```text
Alt+l       open URL
Alt+y       copy URL
Alt+o       copy terminal output
Shift+PgUp  scroll up
Shift+PgDn  scroll down
```

## Status bar

`dwmblocks` provides the status bar.

The default blocks are:

```text
internet | brightness | volume | battery | clock
```

Status scripts are installed under:

```text
~/.local/bin/statusbar/
```

## Image handling

`nsxiv` is used as the default image viewer.

The setup includes:

- directory-aware image opening
- Thunar integration
- common image MIME associations
- Trash support
- nsxiv key handling

The file-manager helper is:

```text
~/.local/bin/nsxiv-rifle
```

Stock nsxiv scaling behavior is preserved.

## Desktop configuration

The dotfiles configure, among other things:

- bash
- dunst
- Firefox
- GTK
- mpv
- Neovim
- nsxiv
- Redshift
- Thunderbird
- Thunar
- Xresources
- yt-dlp
- Zathura

The graphical session is started through `.xinitrc` and launches:

```text
Xresources
Redshift
wallpaper
dunst
dwmblocks
dwm
```

Caps Lock and Escape are swapped for the X session.

## Audio

Audio uses PipeWire and WirePlumber with PulseAudio and JACK compatibility.

Audio device handling uses `wpctl`.

## Firefox and Thunderbird

Firefox and Thunderbird receive system policies from the dotfiles repository.

Firefox configuration includes privacy and interface preferences together with:

- uBlock Origin
- Dark Reader
- Enhancer for YouTube
- I Still Don't Care About Cookies

## Wallpaper

The default wallpaper is:

```text
dante-et-vergil-dans-le-neuvieme-cercle-de-l'enfer.jpg
```

It is installed to:

```text
~/Pictures/Wallpapers/
```

## Redshift and keyboard

The installer asks for latitude and longitude for Redshift.

Default temperatures are:

```text
Day:   6500 K
Night: 4500 K
```

A US keyboard layout is assumed by default. Other console and X11 layouts can be selected during installation.

## NVIDIA

NVIDIA driver installation is optional.

If NVIDIA hardware is detected, the installer offers to install the appropriate driver packages for the distribution.

## Repository layout

```text
dwm-install/
├── LICENSE
├── README.md
├── arch/
│   └── dwm-install.sh
└── debian/
    └── dwm-install.sh
```

## Notes

The scripts are intended primarily for fresh or minimal systems.

Existing matching configuration files may be overwritten.

Machine-specific configuration and Polkit configuration are intentionally kept outside the public installer.

## License

Made by rabbi-lion.

Licensed under the GNU General Public License version 3.

See `LICENSE` for the full license text.

Programs built or installed by these scripts retain their own respective licenses.
