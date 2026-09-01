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
    pipewire-jack \
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
    zathura-pdf-poppler \
    zip


# ------------------------------------------------------------
# 4. Audio output selection
# ------------------------------------------------------------

echo
echo "==> Configuring audio output..."

if command -v wpctl >/dev/null 2>&1; then
    # PipeWire normally uses socket activation, but start the user services
    # now so that sinks are available during the installer.
    systemctl --user start \
        pipewire.service \
        pipewire-pulse.service \
        wireplumber.service \
        >/dev/null 2>&1 || true

    SINK_LIST=""

    # Give WirePlumber a few seconds to discover the audio hardware.
    for _ in {1..10}; do
        SINK_LIST="$(wpctl list audio sinks 2>/dev/null || true)"

        if [[ -n "$SINK_LIST" ]]; then
            break
        fi

        sleep 1
    done

    if [[ -n "$SINK_LIST" ]]; then
        WPCTL_STATUS="$(wpctl status 2>/dev/null || true)"

        declare -a SINK_IDS=()
        declare -a SINK_NAMES=()
        declare -a SINK_DESCRIPTIONS=()
        declare -a SINK_HINTS=()
        declare -a SINK_DEFAULTS=()

        audio_sink_description() {
            local sink_id="$1"
            local fallback_name="$2"
            local status_line=""
            local description=""

            status_line="$(
                printf '%s\n' "$WPCTL_STATUS" \
                    | grep -m1 -E "[[:space:]]\*?[[:space:]]*${sink_id}\.[[:space:]]" \
                    || true
            )"

            if [[ -n "$status_line" ]]; then
                description="$(
                    printf '%s\n' "$status_line" \
                        | sed -E \
                            -e "s/^.*[[:space:]]\*?[[:space:]]*${sink_id}\.[[:space:]]+//" \
                            -e 's/[[:space:]]+\[vol:[^]]+\]$//'
                )"
            fi

            if [[ -z "$description" ]]; then
                description="$(
                    wpctl inspect "$sink_id" 2>/dev/null \
                        | awk '
                            {
                                line = $0
                                sub(/^[[:space:]*]+/, "", line)
                                prefix = "node.description = \""

                                if (index(line, prefix) == 1) {
                                    line = substr(line, length(prefix) + 1)
                                    sub(/\"$/, "", line)
                                    print line
                                    exit
                                }
                            }
                        ' \
                        || true
                )"
            fi

            printf '%s' "${description:-$fallback_name}"
        }

        audio_sink_hint() {
            local text="${1,,} ${2,,}"

            case "$text" in
                *hdmi*|*displayport*|*"display port"*)
                    printf '%s' "HDMI/DisplayPort - monitor or TV audio"
                    ;;
                *iec958*|*spdif*|*"s/pdif"*)
                    printf '%s' "S/PDIF - optical/digital audio"
                    ;;
                *usb*)
                    printf '%s' "USB audio - headset, DAC or interface"
                    ;;
                *analog*|*speaker*|*headphone*)
                    printf '%s' "Analog - normal speakers/headphones"
                    ;;
                *)
                    printf '%s' "Audio output"
                    ;;
            esac
        }

        while IFS=$'\t' read -r sink_id sink_name sink_type sink_default; do
            [[ "$sink_id" =~ ^[0-9]+$ ]] || continue
            [[ "$sink_type" == "audio/sink" ]] || continue

            sink_description="$(audio_sink_description "$sink_id" "$sink_name")"
            sink_hint="$(audio_sink_hint "$sink_description" "$sink_name")"

            SINK_IDS+=("$sink_id")
            SINK_NAMES+=("$sink_name")
            SINK_DESCRIPTIONS+=("$sink_description")
            SINK_HINTS+=("$sink_hint")
            SINK_DEFAULTS+=("$sink_default")
        done <<< "$SINK_LIST"

        if (( ${#SINK_IDS[@]} > 0 )); then
            echo
            echo "Available audio outputs:"
            echo

            for i in "${!SINK_IDS[@]}"; do
                current=""

                if [[ "${SINK_DEFAULTS[$i]}" == *"*"* ]]; then
                    current=" [current default]"
                fi

                printf '  %d) %s%s\n' \
                    "$((i + 1))" \
                    "${SINK_DESCRIPTIONS[$i]}" \
                    "$current"
                printf '     %s\n' "${SINK_HINTS[$i]}"
            done

            echo
            echo "Note: GPU DisplayPort audio is commonly labelled HDMI by PipeWire."
            echo

            while true; do
                AUDIO_CHOICE=""

                read -rp \
                    "Default audio output [1-${#SINK_IDS[@]}, Enter = keep current]: " \
                    AUDIO_CHOICE \
                    </dev/tty

                if [[ -z "$AUDIO_CHOICE" ]]; then
                    echo "Keeping the current default audio output."
                    break
                fi

                if [[ "$AUDIO_CHOICE" =~ ^[0-9]+$ ]] \
                    && (( AUDIO_CHOICE >= 1 && AUDIO_CHOICE <= ${#SINK_IDS[@]} )); then

                    AUDIO_INDEX=$((AUDIO_CHOICE - 1))
                    AUDIO_SINK_ID="${SINK_IDS[$AUDIO_INDEX]}"

                    if wpctl set-default "$AUDIO_SINK_ID"; then
                        echo
                        echo "Default audio output set to:"
                        echo "  ${SINK_DESCRIPTIONS[$AUDIO_INDEX]}"
                        echo
                        echo "WirePlumber will remember this selection across restarts."
                    else
                        echo
                        echo "WARNING: Could not set the selected audio output."
                        echo "You can configure it later with: wpctl status"
                    fi

                    break
                fi

                echo "Please choose a number from 1 to ${#SINK_IDS[@]}, or press Enter."
            done
        else
            echo
            echo "WARNING: No usable PipeWire audio sinks were found."
            echo "Skipping audio output selection."
            echo "You can configure it later with: wpctl status"
        fi
    else
        echo
        echo "WARNING: PipeWire/WirePlumber did not report any audio sinks."
        echo "Skipping audio output selection."
        echo "You can configure it later with: wpctl status"
    fi
else
    echo
    echo "WARNING: wpctl is unavailable."
    echo "Skipping audio output selection."
fi


# ------------------------------------------------------------
# 5. Optional NVIDIA driver
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
# 6. Source directory
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
# 7. Source repository helper
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
# 8. Build dwm / st / dmenu / dwmblocks
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
# 9. Build nsxiv
# ------------------------------------------------------------

clone_or_update nsxiv "$NSXIV_REPO"

echo
echo "==> Building nsxiv..."

make -C "$SRC_DIR/nsxiv" clean
make -C "$SRC_DIR/nsxiv"
sudo make -C "$SRC_DIR/nsxiv" install-all


# ------------------------------------------------------------
# 10. Dotfiles
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
# 11. Default image viewer
# ------------------------------------------------------------

echo
echo "==> Setting nsxiv as the default image viewer..."

NSXIV_DESKTOP="$HOME/.local/share/applications/nsxiv.desktop"

if [[ ! -f "$NSXIV_DESKTOP" ]]; then
    echo "ERROR: nsxiv desktop entry is missing:"
    echo "  $NSXIV_DESKTOP"
    exit 1
fi

for type in \
    image/jpeg \
    image/png \
    image/gif \
    image/webp \
    image/bmp \
    image/tiff \
    image/svg+xml \
    image/avif \
    image/heif \
    image/jxl
do
    xdg-mime default nsxiv.desktop "$type"
done


# ------------------------------------------------------------
# 12. Firefox configuration
# ------------------------------------------------------------

echo
echo "==> Installing Firefox configuration..."

FIREFOX_POLICY="$DOTFILES_DIR/system/etc/firefox/policies/policies.json"

if [[ ! -f "$FIREFOX_POLICY" ]]; then
    echo "ERROR: Firefox policy is missing:"
    echo "  $FIREFOX_POLICY"
    exit 1
fi

sudo install -Dm644 \
    "$FIREFOX_POLICY" \
    /etc/firefox/policies/policies.json


# ------------------------------------------------------------
# 13. Thunderbird configuration
# ------------------------------------------------------------

echo
echo "==> Installing Thunderbird configuration..."

THUNDERBIRD_POLICY="$DOTFILES_DIR/system/usr/lib/thunderbird/distribution/policies.json"

if [[ ! -f "$THUNDERBIRD_POLICY" ]]; then
    echo "ERROR: Thunderbird policy is missing:"
    echo "  $THUNDERBIRD_POLICY"
    exit 1
fi

sudo install -Dm644 \
    "$THUNDERBIRD_POLICY" \
    /usr/lib/thunderbird/distribution/policies.json


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
# 19. Remove cloned dotfiles
# ------------------------------------------------------------

echo
echo "==> Removing cloned dotfiles source..."

rm -rf -- "$DOTFILES_DIR"


# ------------------------------------------------------------
# 20. Finish
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Post-install complete."
echo "============================================================"
echo
echo "Installed:"
echo "  - XLibre"
echo "  - applications"
echo "  - PipeWire / WirePlumber audio"
echo "  - dwm"
echo "  - st"
echo "  - dmenu"
echo "  - dwmblocks"
echo "  - nsxiv"
echo "  - nsxiv default image association"
echo "  - dotfiles"
echo "  - Firefox configuration"
echo "  - Thunderbird configuration"
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
echo "GTK settings are provided by the dotfiles repository."


# ------------------------------------------------------------
# 21. Delete installer
# ------------------------------------------------------------

echo
echo "==> Removing installer..."

rm -f -- "$SCRIPT_PATH"


# ------------------------------------------------------------
# 22. Reboot
# ------------------------------------------------------------

echo

if confirm "Reboot now?"; then
    sudo reboot
else
    echo
    echo "Reboot before using the completed X/dwm environment."
fi
