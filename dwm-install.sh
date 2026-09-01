#!/bin/bash
set -euo pipefail

# ============================================================
# Arch Linux + XLibre + dwm post-install
# ============================================================

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"

SRC_DIR="$HOME/src"

DWM_REPO="https://github.com/rabbi-lion/dwm.git"
ST_REPO="https://github.com/rabbi-lion/st.git"
DMENU_REPO="https://git.suckless.org/dmenu"
DWMBLOCKS_REPO="https://github.com/rabbi-lion/dwmblocks.git"
NSXIV_REPO="https://github.com/rabbi-lion/nsxiv.git"
DOTFILES_REPO="https://github.com/rabbi-lion/dotfiles.git"

DEFAULT_WALLPAPER="dante-et-vergil-dans-le-neuvieme-cercle-de-l'enfer.jpg"


# ------------------------------------------------------------
# Basic checks
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Run this script as your normal user, not as root."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    echo "ERROR: This installer is intended for Arch Linux."
    exit 1
fi

confirm() {
    local prompt="$1"
    local answer=""

    read -rp "$prompt [y/N]: " answer </dev/tty

    case "$answer" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo
echo "This will install the rabbi-lion dwm environment and overwrite"
echo "matching configuration files in your home directory."
echo

if ! confirm "Continue?"; then
    echo "Installation cancelled."
    exit 0
fi

sudo -v


# ------------------------------------------------------------
# 1. Home directories
# ------------------------------------------------------------

echo
echo "==> Creating home directories..."

mkdir -p \
    "$HOME/Documents" \
    "$HOME/Downloads" \
    "$HOME/Music" \
    "$HOME/Pictures" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Videos"


# ------------------------------------------------------------
# 2. XLibre
# ------------------------------------------------------------

echo
echo "==> Installing XLibre..."

sudo pacman -S --needed curl

XLIBRE_KEY="$(mktemp)"

curl -fsSL \
    https://xlibre-arch.github.io/xlibre-archlinux.asc \
    -o "$XLIBRE_KEY"

sudo pacman-key --add "$XLIBRE_KEY"
sudo pacman-key --finger B97F7C613F359424
sudo pacman-key --lsign-key B97F7C613F359424

rm -f "$XLIBRE_KEY"

if ! grep -q '^\[xlibre-stable\]$' /etc/pacman.conf; then
    printf '\n[xlibre-stable]\nServer = https://packages.xlibre.net/arch/stable/$arch\n' \
        | sudo tee -a /etc/pacman.conf >/dev/null
fi

sudo pacman -Syyu
sudo pacman -S --needed xlibre-meta


# ------------------------------------------------------------
# 3. Regular packages
# ------------------------------------------------------------

echo
echo "==> Installing packages..."

sudo pacman -S --needed \
    brightnessctl \
    dunst \
    fastfetch \
    feh \
    ffmpegthumbnailer \
    firefox \
    git \
    gvfs \
    htop \
    imlib2 \
    keepassxc \
    libexif \
    maim \
    mousepad \
    mpv \
    pciutils \
    pipewire \
    pipewire-pulse \
    pulsemixer \
    redshift \
    thunar \
    thunderbird \
    transmission-cli \
    tree \
    ttf-ibm-plex \
    tumbler \
    unzip \
    wireplumber \
    xarchiver \
    xclip \
    xdg-utils \
    xorg-setxkbmap \
    xorg-xinit \
    xorg-xrdb \
    xorg-xset \
    yt-dlp \
    zathura \
    zathura-pdf-mupdf \
    zathura-pdf-poppler \
    zip


# ------------------------------------------------------------
# 4. Optional NVIDIA driver
# ------------------------------------------------------------

echo
echo "==> Checking graphics hardware..."

GPU_INFO="$(lspci -k -d ::03xx || true)"
printf '%s\n' "$GPU_INFO"

echo
echo "Kernel:"
uname -r

if printf '%s\n' "$GPU_INFO" | grep -qi 'NVIDIA'; then
    echo
    echo "NVIDIA GPU detected."
    echo
    echo "nvidia-open is intended for supported newer NVIDIA GPUs."
    echo "Older NVIDIA GPUs may require a different legacy driver."
    echo

    if confirm "Install nvidia-open, nvidia-settings and nvidia-utils?"; then
        sudo pacman -S --needed \
            nvidia-open \
            nvidia-settings \
            nvidia-utils
    else
        echo "Skipping NVIDIA driver installation."
    fi
else
    echo
    echo "No NVIDIA display controller detected."
    echo "Skipping NVIDIA driver installation."
fi


# ------------------------------------------------------------
# 5. Source directory
# ------------------------------------------------------------

echo
echo "==> Preparing source directory..."

mkdir -p "$SRC_DIR"

if [[ ! -O "$SRC_DIR" ]]; then
    echo "ERROR: $SRC_DIR is not owned by $USER."
    echo
    echo "Fix the ownership and run the installer again:"
    echo
    echo "  sudo chown -R $USER:$(id -gn) \"$SRC_DIR\""
    exit 1
fi


# ------------------------------------------------------------
# 6. Source repository helper
# ------------------------------------------------------------

clone_or_update() {
    local name="$1"
    local repo="$2"
    local dir="$SRC_DIR/$name"

    if [[ -d "$dir/.git" ]]; then
        echo "==> Updating $name..."

        git -C "$dir" remote set-url origin "$repo"
        git -C "$dir" pull --ff-only

    elif [[ -e "$dir" ]]; then
        echo "ERROR: $dir already exists but is not a Git repository."
        exit 1

    else
        echo "==> Cloning $name..."
        git clone "$repo" "$dir"
    fi
}


# ------------------------------------------------------------
# 7. Build dwm / st / dmenu / dwmblocks
# ------------------------------------------------------------

build_suckless() {
    local name="$1"
    local repo="$2"
    local dir="$SRC_DIR/$name"

    clone_or_update "$name" "$repo"

    echo "==> Building $name..."

    make -C "$dir" clean
    make -C "$dir"
    sudo make -C "$dir" install
}

build_suckless dmenu "$DMENU_REPO"
build_suckless dwm "$DWM_REPO"
build_suckless st "$ST_REPO"
build_suckless dwmblocks "$DWMBLOCKS_REPO"


# ------------------------------------------------------------
# 8. Build nsxiv
# ------------------------------------------------------------

clone_or_update nsxiv "$NSXIV_REPO"

echo
echo "==> Building nsxiv..."

make -C "$SRC_DIR/nsxiv" clean
make -C "$SRC_DIR/nsxiv"
sudo make -C "$SRC_DIR/nsxiv" install-all


# ------------------------------------------------------------
# 9. Dotfiles
# ------------------------------------------------------------

echo
echo "==> Installing dotfiles..."

DOTFILES_DIR="$SRC_DIR/dotfiles"

clone_or_update dotfiles "$DOTFILES_REPO"

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local"

cp -a "$DOTFILES_DIR/.bash_profile" "$HOME/"
cp -a "$DOTFILES_DIR/.bashrc" "$HOME/"
cp -a "$DOTFILES_DIR/.xinitrc" "$HOME/"
cp -a "$DOTFILES_DIR/.Xresources" "$HOME/"

cp -a "$DOTFILES_DIR/.config/." "$HOME/.config/"
cp -a "$DOTFILES_DIR/.local/." "$HOME/.local/"


# ------------------------------------------------------------
# 10. Default wallpaper
# ------------------------------------------------------------

echo
echo "==> Installing default wallpaper..."

if [[ ! -f "$DOTFILES_DIR/$DEFAULT_WALLPAPER" ]]; then
    echo "ERROR: Default wallpaper is missing:"
    echo "  $DOTFILES_DIR/$DEFAULT_WALLPAPER"
    exit 1
fi

install -Dm644 \
    "$DOTFILES_DIR/$DEFAULT_WALLPAPER" \
    "$HOME/Pictures/Wallpapers/$DEFAULT_WALLPAPER"


# ------------------------------------------------------------
# 11. Redshift location
# ------------------------------------------------------------

echo
echo "==> Configuring Redshift..."

while true; do
    REDSHIFT_LAT=""

    read -rp "Latitude: " REDSHIFT_LAT </dev/tty

    if [[ "$REDSHIFT_LAT" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        break
    fi

    echo "Please enter a numeric latitude, for example: 45.81"
done

while true; do
    REDSHIFT_LON=""

    read -rp "Longitude: " REDSHIFT_LON </dev/tty

    if [[ "$REDSHIFT_LON" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        break
    fi

    echo "Please enter a numeric longitude, for example: 15.96"
done

sed -i \
    -e "s/REDSHIFT_LAT/$REDSHIFT_LAT/g" \
    -e "s/REDSHIFT_LON/$REDSHIFT_LON/g" \
    "$HOME/.config/redshift.conf"


# ------------------------------------------------------------
# 12. Touchpad
# ------------------------------------------------------------

echo
echo "==> Installing natural-scrolling touchpad configuration..."

TOUCHPAD_CONFIG="$DOTFILES_DIR/system/etc/X11/xorg.conf.d/30-touchpad.conf"

if [[ ! -f "$TOUCHPAD_CONFIG" ]]; then
    echo "ERROR: Touchpad configuration is missing:"
    echo "  $TOUCHPAD_CONFIG"
    exit 1
fi

sudo install -Dm644 \
    "$TOUCHPAD_CONFIG" \
    /etc/X11/xorg.conf.d/30-touchpad.conf


# ------------------------------------------------------------
# 13. Optional keyboard localization
# ------------------------------------------------------------

echo
echo "==> Keyboard localization..."
echo
echo "The base installation is assumed to use a US keyboard."
echo

if confirm "Do you want to change the keyboard localization?"; then
    echo
    echo "Console and X11 layout names may differ."
    echo "Example for Croatian:"
    echo "  Console keymap: croat"
    echo "  X11 layout:     hr"
    echo

    VC_KEYMAP=""
    X11_LAYOUT=""

    read -rp "Console keymap [us]: " VC_KEYMAP </dev/tty
    VC_KEYMAP="${VC_KEYMAP:-us}"

    read -rp "X11 keyboard layout [us]: " X11_LAYOUT </dev/tty
    X11_LAYOUT="${X11_LAYOUT:-us}"

    echo
    echo "Setting console keymap to: $VC_KEYMAP"
    sudo localectl set-keymap --no-convert "$VC_KEYMAP"

    echo "Setting X11 keyboard layout to: $X11_LAYOUT"
    sudo localectl --no-convert set-x11-keymap "$X11_LAYOUT"
else
    echo "Keeping the existing US keyboard configuration."
fi

# Caps Lock / Escape swapping is handled by ~/.xinitrc:
#
# setxkbmap -option caps:swapescape


# ------------------------------------------------------------
# 14. tty1 username pre-fill
# ------------------------------------------------------------

echo
echo "==> Configuring tty1 login..."

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

printf \
    '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty -o '\''-- %s'\'' --skip-login --noreset --noclear - ${TERM}\n' \
    "$USER" \
    | sudo tee \
        /etc/systemd/system/getty@tty1.service.d/skip-username.conf \
        >/dev/null

sudo systemctl daemon-reload

# Do NOT restart getty@tty1 here.
# The installer may itself be running from tty1.


# ------------------------------------------------------------
# 15. Finish
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Post-install complete."
echo "============================================================"
echo
echo "Installed:"
echo "  - XLibre"
echo "  - applications"
echo "  - dwm"
echo "  - st"
echo "  - dmenu"
echo "  - dwmblocks"
echo "  - nsxiv"
echo "  - dotfiles"
echo "  - default wallpaper"
echo "  - natural touchpad scrolling"
echo "  - tty1 username pre-fill"
echo
echo "Created:"
echo "  - ~/Documents"
echo "  - ~/Downloads"
echo "  - ~/Music"
echo "  - ~/Pictures"
echo "  - ~/Pictures/Wallpapers"
echo "  - ~/Videos"
echo
echo "The default wallpaper is:"
echo "  ~/Pictures/Wallpapers/$DEFAULT_WALLPAPER"
echo
echo "Static wallpaper startup is handled by:"
echo "  ~/.local/bin/wallpaper"
echo
echo "The optional slideshow remains available as:"
echo "  ~/.local/bin/wallpaper-slideshow"
echo
echo "The Caps Lock / Escape swap is handled by ~/.xinitrc."
echo
echo "GTK settings are intentionally not configured."


# ------------------------------------------------------------
# 16. Delete installer
# ------------------------------------------------------------

echo
echo "==> Removing installer..."

rm -f -- "$SCRIPT_PATH"


# ------------------------------------------------------------
# 17. Reboot
# ------------------------------------------------------------

echo

if confirm "Reboot now?"; then
    sudo reboot
else
    echo
    echo "Reboot before using the completed X/dwm environment."
fi