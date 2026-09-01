#!/bin/bash
set -euo pipefail

# ============================================================
# Debian + XLibre + dwm post-install
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

if [[ ! -f /etc/debian_version ]]; then
    echo "ERROR: This installer is intended for Debian."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required."
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

. /etc/os-release

DEBIAN_CODENAME="${VERSION_CODENAME:-unknown}"
DEBIAN_ARCH="$(dpkg --print-architecture)"

echo
echo "Debian release: ${PRETTY_NAME:-Debian}"
echo "Codename:       $DEBIAN_CODENAME"
echo "Architecture:   $DEBIAN_ARCH"
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
# 2. Update Debian
# ------------------------------------------------------------

echo
echo "==> Updating Debian..."

sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg


# ------------------------------------------------------------
# 3. XLibre / Xorg
# ------------------------------------------------------------

XLIBRE_INSTALLED=false

echo
echo "==> Display server..."
echo
echo "XLibre is available through an unofficial Debian repository."
echo

if confirm "Install XLibre?"; then

    case "$DEBIAN_CODENAME" in

        trixie)
            XLIBRE_COMPONENT="stable"

            echo
            echo "==> Ensuring Trixie backports are enabled..."

            if ! grep -RqsE \
                '(^deb .*trixie-backports|Suites:.*trixie-backports)' \
                /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null
            then
                sudo tee \
                    /etc/apt/sources.list.d/dwm-install-backports.sources \
                    >/dev/null <<'EOF'
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
            fi
            ;;

        forky)
            XLIBRE_COMPONENT="testing"
            ;;

        *)
            echo
            echo "WARNING: Automatic XLibre setup is not configured for:"
            echo "  $DEBIAN_CODENAME"
            echo
            echo "Falling back to regular Debian Xorg."
            XLIBRE_COMPONENT=""
            ;;
    esac

    if [[ -n "$XLIBRE_COMPONENT" ]]; then

        case "$DEBIAN_ARCH" in
            amd64|arm64)
                ;;
            *)
                echo
                echo "WARNING: XLibre repository setup has not been"
                echo "validated by this installer for $DEBIAN_ARCH."
                echo "Falling back to Xorg."
                XLIBRE_COMPONENT=""
                ;;
        esac
    fi

    if [[ -n "$XLIBRE_COMPONENT" ]]; then

        echo
        echo "==> Adding XLibre repository..."

        sudo install -m755 -d /usr/share/keyrings

        curl -fsSL \
            https://mrchicken.nexussfan.cz/publickey.asc \
            | gpg --dearmor \
            | sudo tee /usr/share/keyrings/NexusSfan.pgp \
                >/dev/null

        sudo chmod a+r /usr/share/keyrings/NexusSfan.pgp

        sudo tee \
            /etc/apt/sources.list.d/xlibre-debian.sources \
            >/dev/null <<EOF
Types: deb
URIs: https://xlibre-debian.github.io/debian/
Suites: main
Components: $XLIBRE_COMPONENT
Signed-By: /usr/share/keyrings/NexusSfan.pgp
EOF

        sudo apt-get update

        echo
        echo "==> Installing XLibre..."

        sudo apt-get install -y \
            xlibre \
            xlibre-archive-keyring

        XLIBRE_INSTALLED=true
    fi
fi

if [[ "$XLIBRE_INSTALLED" == false ]]; then
    echo
    echo "==> Installing Debian Xorg..."

    sudo apt-get install -y xorg
fi


# ------------------------------------------------------------
# 4. Regular packages
# ------------------------------------------------------------

echo
echo "==> Installing applications..."

sudo apt-get install -y \
    brightnessctl \
    dunst \
    fastfetch \
    feh \
    ffmpegthumbnailer \
    firefox-esr \
    git \
    gvfs \
    htop \
    keepassxc \
    maim \
    mousepad \
    mpv \
    neovim \
    pciutils \
    pipewire \
    pipewire-pulse \
    pulsemixer \
    redshift \
    thunar \
    thunderbird \
    transmission-cli \
    tree \
    tumbler \
    unzip \
    wireplumber \
    x11-xkb-utils \
    x11-xserver-utils \
    xarchiver \
    xclip \
    xdg-utils \
    xinit \
    yt-dlp \
    zathura \
    zathura-pdf-poppler \
    zip


# ------------------------------------------------------------
# 5. IBM Plex font
# ------------------------------------------------------------

echo
echo "==> Installing IBM Plex font..."

if apt-cache show fonts-ibm-plex >/dev/null 2>&1; then
    sudo apt-get install -y fonts-ibm-plex
else
    echo
    echo "WARNING: fonts-ibm-plex is not available from your"
    echo "currently enabled Debian repositories."
    echo
    echo "The package is in Debian contrib."
    echo "Enable contrib and install it later with:"
    echo
    echo "  sudo apt-get install fonts-ibm-plex"
fi


# ------------------------------------------------------------
# 6. Source build dependencies
# ------------------------------------------------------------

echo
echo "==> Installing source build dependencies..."

sudo apt-get install -y \
    build-essential \
    libexif-dev \
    libfontconfig-dev \
    libfreetype-dev \
    libimlib2-dev \
    libx11-dev \
    libxft-dev \
    libxinerama-dev \
    pkg-config


# ------------------------------------------------------------
# 7. Optional NVIDIA driver
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
    echo "Debian's open NVIDIA kernel modules support"
    echo "Turing and newer NVIDIA GPUs."
    echo

    if confirm "Install Debian's open NVIDIA driver?"; then

        if apt-cache policy nvidia-open-kernel-dkms \
            | grep -q 'Candidate: (none)'
        then
            echo
            echo "ERROR: NVIDIA packages are not available."
            echo
            echo "Your Debian repositories probably need:"
            echo "  contrib"
            echo "  non-free"
            echo "  non-free-firmware"
            echo
            echo "Enable them and rerun the installer."
            exit 1
        fi

        echo
        echo "==> Installing NVIDIA driver..."

        sudo apt-get install -y \
            "linux-headers-$(uname -r)" \
            nvidia-driver \
            nvidia-open-kernel-dkms \
            nvidia-settings

    else
        echo "Skipping NVIDIA driver installation."
    fi

else
    echo
    echo "No NVIDIA display controller detected."
    echo "Skipping NVIDIA driver installation."
fi


# ------------------------------------------------------------
# 8. Source directory
# ------------------------------------------------------------

echo
echo "==> Preparing source directory..."

mkdir -p "$SRC_DIR"

if [[ ! -O "$SRC_DIR" ]]; then
    echo "ERROR: $SRC_DIR is not owned by $USER."
    echo
    echo "Fix its ownership and run this installer again:"
    echo
    echo "  sudo chown -R $USER:$(id -gn) \"$SRC_DIR\""
    exit 1
fi


# ------------------------------------------------------------
# 9. Repository helper
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
# 10. Debian X11 build paths
# ------------------------------------------------------------

MULTIARCH="$(gcc -print-multiarch)"

X11INC="/usr/include"

if [[ -n "$MULTIARCH" ]]; then
    X11LIB="/usr/lib/$MULTIARCH"
else
    X11LIB="/usr/lib"
fi

echo
echo "==> Debian X11 build paths:"
echo "    include: $X11INC"
echo "    library: $X11LIB"


# ------------------------------------------------------------
# 11. Build dwm / st / dmenu / dwmblocks
# ------------------------------------------------------------

build_suckless() {
    local name="$1"
    local repo="$2"
    local dir="$SRC_DIR/$name"

    clone_or_update "$name" "$repo"

    echo
    echo "==> Building $name..."

    make -C "$dir" clean \
        X11INC="$X11INC" \
        X11LIB="$X11LIB"

    make -C "$dir" \
        X11INC="$X11INC" \
        X11LIB="$X11LIB"

    sudo make -C "$dir" install \
        X11INC="$X11INC" \
        X11LIB="$X11LIB"
}

build_suckless dmenu "$DMENU_REPO"
build_suckless dwm "$DWM_REPO"
build_suckless st "$ST_REPO"
build_suckless dwmblocks "$DWMBLOCKS_REPO"


# ------------------------------------------------------------
# 12. Build nsxiv
# ------------------------------------------------------------

clone_or_update nsxiv "$NSXIV_REPO"

echo
echo "==> Building nsxiv..."

make -C "$SRC_DIR/nsxiv" clean
make -C "$SRC_DIR/nsxiv"
sudo make -C "$SRC_DIR/nsxiv" install-all


# ------------------------------------------------------------
# 13. Dotfiles
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
# 14. Default wallpaper
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
# 15. Redshift location
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
# 16. Touchpad
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
# 17. Optional keyboard localization
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
# 18. tty1 username pre-fill
# ------------------------------------------------------------

echo
echo "==> Configuring tty1 login..."

if command -v systemctl >/dev/null 2>&1; then

    sudo mkdir -p \
        /etc/systemd/system/getty@tty1.service.d

    printf \
        '[Service]\nExecStart=\nExecStart=-/sbin/agetty -o '\''-- %s'\'' --skip-login --noreset --noclear - ${TERM}\n' \
        "$USER" \
        | sudo tee \
            /etc/systemd/system/getty@tty1.service.d/skip-username.conf \
            >/dev/null

    sudo systemctl daemon-reload

else
    echo
    echo "WARNING: systemctl is unavailable."
    echo "Skipping the tty1 getty override."
fi


# ------------------------------------------------------------
# 19. Finish
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Debian dwm post-install complete."
echo "============================================================"
echo

if [[ "$XLIBRE_INSTALLED" == true ]]; then
    echo "Display server: XLibre"
else
    echo "Display server: Xorg"
fi

echo
echo "Installed:"
echo "  - applications"
echo "  - dwm"
echo "  - st"
echo "  - dmenu"
echo "  - dwmblocks"
echo "  - nsxiv"
echo "  - dotfiles"
echo "  - default wallpaper"
echo "  - natural touchpad scrolling"
echo
echo "Created:"
echo "  - ~/Documents"
echo "  - ~/Downloads"
echo "  - ~/Music"
echo "  - ~/Pictures"
echo "  - ~/Pictures/Wallpapers"
echo "  - ~/Videos"
echo
echo "Default wallpaper:"
echo "  ~/Pictures/Wallpapers/$DEFAULT_WALLPAPER"
echo
echo "Static wallpaper helper:"
echo "  ~/.local/bin/wallpaper"
echo
echo "Optional slideshow:"
echo "  ~/.local/bin/wallpaper-slideshow"
echo
echo "Caps Lock / Escape swapping is handled by ~/.xinitrc."
echo
echo "GTK settings are intentionally not configured."


# ------------------------------------------------------------
# 20. Delete installer
# ------------------------------------------------------------

echo
echo "==> Removing installer..."

rm -f -- "$SCRIPT_PATH"


# ------------------------------------------------------------
# 21. Reboot
# ------------------------------------------------------------

echo

if confirm "Reboot now?"; then
    sudo reboot
else
    echo
    echo "Reboot before using the completed X/dwm environment."
fi