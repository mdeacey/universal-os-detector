#!/bin/bash

set -eo pipefail
trap 'log "Error encountered at line ${LINENO:-unknown} while executing command: ${BASH_COMMAND:-unknown}" "ERROR"' ERR

LOG_FILE=${LOG_FILE:-~/universal-os-detector.log}
DEBUG_MODE=${DEBUG_MODE:-0}

cleanup() {
    log "Cleaning up resources..." INFO
    log "Removing log file..." INFO
    rm -f "$LOG_FILE".lock
    log "Cleanup completed" INFO
    log "Exiting..." INFO
    exit 0
}

trap 'log "Received termination signal. Exiting." "WARN"; cleanup' SIGINT SIGTERM

log() {
    local message="${1:-}"
    local level="${2:-INFO}"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')

    local color
    case "$level" in
        ERROR) color='\033[0;31m' ;;
        WARN) color='\033[0;33m' ;;
        INFO) color='\033[0;30m' ;;
        SYSTEM) color='\033[0;37m' ;;
        DEBUG) color='\033[0m' ;;
        *) color='\033[0m' ;;
    esac

    echo -e "$current_time [$level]: $message" >> "$LOG_FILE"

    if [ "$DEBUG_MODE" -eq 1 ] || [ "$level" = "SYSTEM" ] || [ "$level" = "ERROR" ]; then
        echo -e "${color}$current_time [$level]: $message${COLOR_RESET}"
    fi
}

check_file_access() {
    local file=$1
    log "Checking file access for: $file..." INFO

    if [ ! -f "$file" ]; then
        log "File $file does not exist." ERROR
        return 1
    elif [ ! -r "$file" ]; then
        log "File $file is not readable." ERROR
        return 1
    elif [ ! -w "$file" ]; then
        log "File $file is not writable." WARN
    fi
}

check_command() {
    local required_command="$1"
    local version_flag="${2:---version}"
    local minimum_version="${3:-}"

    if ! command -v "$required_command" &>/dev/null; then
        log "Error: Command '$required_command' is not available." ERROR
        return 1
    fi

    if [ -n "$minimum_version" ]; then
        current_version=$($required_command $version_flag 2>&1 | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+')
        if [ "$(printf '%s\n' "$minimum_version" "$current_version" | sort -V | head -n1)" != "$minimum_version" ]; then
            log "Error: Command '$required_command' version ($current_version) does not meet minimum version ($minimum_version)." ERROR
            return 1
        fi
    fi
}

lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

function_tests() {
    log "Running function tests..." INFO
    log "Checking command availability..." INFO
    check_command "uname" || exit 1
    check_command "tr" || exit 1
    check_command "grep" || exit 1
    check_file_access "$LOG_FILE" || exit 1
    log "All function tests passed." INFO
}

detect_container() {
    log "Detecting container environment..." INFO
    if [ -f /.dockerenv ]; then
        log "Running inside Docker" SYSTEM
    elif grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        log "Running inside a container (Docker/LXC)" SYSTEM
    elif grep -q 'VxID' /proc/self/status 2>/dev/null; then
        log "Running inside OpenVZ" SYSTEM
    else
        log "Not running inside a container" SYSTEM
    fi
}

detect_os() {
    log "Detecting operating system..." INFO
    OS=$(uname || echo "Unknown OS")
    OSTYPE="${OSTYPE:-$(uname)}"

    case "$(lowercase "$OSTYPE")" in
        darwin*) OS="MacOS" ;;
        linux*) OS="Linux" ;;
        freebsd*) OS="FreeBSD" ;;
        cygwin*|msys*|mingw*) OS="Windows" ;;
        solaris*) OS="Solaris" ;;
        aix*) OS="AIX" ;;
        *) OS="Unknown" log "Unknown OS detected" WARN ;;
    esac

    log "Operating System: $OS" SYSTEM
}

detect_version() {
    log "Detecting version or distribution..." INFO

    case "$OS" in
        MacOS)
            if command -v sw_vers &>/dev/null; then
                macos_version=$(sw_vers -productVersion)
                macos_name=$(sw_vers -productName)
                case "$macos_version" in
                    14.*) macos_name="Sonoma" ;;
                    13.*) macos_name="Ventura" ;;
                    12.*) macos_name="Monterey" ;;
                    11.*) macos_name="Big Sur" ;;
                    10.15*) macos_name="Catalina" ;;
                    10.14*) macos_name="Mojave" ;;
                    10.13*) macos_name="High Sierra" ;;
                    10.12*) macos_name="Sierra" ;;
                    10.11*) macos_name="El Capitan" ;;
                    10.10*) macos_name="Yosemite" ;;
                    *) 
                        macos_name="Unknown version" 
                        log "Unknown MacOS version: $macos_version" WARN
                        ;;
                esac
                log "Version: $macos_version ($macos_name)" SYSTEM
            else
                log "Command 'sw_vers' not found. Unable to detect MacOS version." ERROR
            fi
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                distro_name=$(grep '^NAME=' /etc/os-release | cut -d '"' -f 2)
                distro_version=$(grep '^VERSION=' /etc/os-release | cut -d '"' -f 2)
                distro_info="$distro_name $distro_version"
            elif command -v lsb_release &>/dev/null; then
                distro_name=$(lsb_release -si)
                distro_version=$(lsb_release -sr)
                distro_info="$distro_name $distro_version"
            else
                distro_info="Unknown Linux distribution"
                log "Unknown Linux distribution, /etc/os-release or lsb_release not found." WARN
            fi
            log "Distribution: $distro_info" SYSTEM
            ;;
        Windows)
            if command -v powershell.exe &>/dev/null; then
                win_name=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).Caption" | tr -d '\r')
                win_version=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).Version" | tr -d '\r')
                win_build=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).BuildNumber" | tr -d '\r')
                if [ -z "$win_name" ] || [ -z "$win_version" ]; then
                    win_info="Unknown Windows version"
                    log "Unable to fully retrieve Windows version info" WARN
                else
                    win_info="$win_name (Version: $win_version, Build: $win_build)"
                fi
            elif command -v cmd.exe &>/dev/null; then
                win_info=$(cmd.exe /c ver | tr -d '\r')
            else
                win_info="Unknown Windows version"
                log "No available method to detect Windows version." WARN
            fi
            log "Windows Version: $win_info" SYSTEM
            ;;
        FreeBSD|OpenBSD|NetBSD)
            if [ -f /etc/os-release ]; then
                bsd_name=$(grep '^NAME=' /etc/os-release | cut -d '"' -f 2)
                bsd_version=$(grep '^VERSION=' /etc/os-release | cut -d '"' -f 2)
                bsd_info="$bsd_name $bsd_version"
            elif command -v uname &>/dev/null; then
                bsd_name=$(uname -s)
                bsd_version=$(uname -r)
                bsd_info="$bsd_name $bsd_version"
            else
                bsd_info="Unknown BSD version"
                log "Unable to detect BSD version, /etc/os-release or uname missing." WARN
            fi
            log "BSD Version: $bsd_info" SYSTEM
            ;;
        Solaris)
            if [ -f /etc/release ]; then
                sol_version=$(grep '^Oracle Solaris' /etc/release | cut -d ':' -f 2 | xargs)
                sol_info="Oracle Solaris $sol_version"
            elif command -v uname &>/dev/null; then
                sol_info="Solaris $(uname -r)"
            else
                sol_info="Unknown Solaris version"
                log "Unable to detect Solaris version" WARN
            fi
            log "Solaris Version: $sol_info" SYSTEM
            ;;
        *)
            log "No version name available for $OS" INFO
            ;;
    esac
}

detect_desktop_env() {
    log "Detecting desktop environment..." INFO
    local desktop_env="Unknown desktop environment"

    if [ "$OS" = "Linux" ]; then
        if [ -n "$XDG_CURRENT_DESKTOP" ]; then
            desktop_env="$XDG_CURRENT_DESKTOP"
        elif [ -n "$DESKTOP_SESSION" ]; then
            desktop_env="$DESKTOP_SESSION"
        elif [ -n "$GDMSESSION" ]; then
            desktop_env="$GDMSESSION"
        else
            if command -v kdialog &>/dev/null; then
                desktop_env="KDE"
            elif command -v gnome-session &>/dev/null; then
                desktop_env="GNOME"
            elif command -v xfce4-session &>/dev/null; then
                desktop_env="Xfce"
            elif command -v mate-session &>/dev/null; then
                desktop_env="MATE"
            elif command -v cinnamon-session &>/dev/null; then
                desktop_env="Cinnamon"
            elif command -v lxsession &>/dev/null; then
                if command -v lxqt-session &>/dev/null; then
                    desktop_env="LXQt"
                else
                    desktop_env="LXDE"
                fi
            elif command -v pantheon-session &>/dev/null; then
                desktop_env="Pantheon"
            elif command -v enlightenment_start &>/dev/null; then
                desktop_env="Enlightenment"
            elif command -v deepin-session &>/dev/null; then
                desktop_env="Deepin"
            else
                desktop_env="Unknown Linux desktop environment"
                log "No known desktop Linux environment binaries found." WARN
            fi
        fi
    elif [ "$OS" = "Windows" ]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            desktop_env="WSL (Windows Subsystem for Linux)"
        elif [[ "$OSTYPE" == "msys"* ]]; then
            desktop_env="Git Bash"
        elif [[ "$OSTYPE" == "cygwin"* ]]; then
            desktop_env="Cygwin"
        elif command -v powershell.exe &>/dev/null; then
            desktop_env="PowerShell"
        else
            desktop_env="Command Prompt (or unknown Windows shell)"
        fi
    elif [ "$OS" = "MacOS" ]; then
        desktop_env="MacOS"
    else
        log "Unsupported operating system: $OS" ERROR
    fi

    log "Desktop Environment: $desktop_env" SYSTEM
}

detect_arch() {
    log "Detecting architecture..." INFO
    ARCH=$(uname -m || echo "Unknown architecture")

    case "$ARCH" in
        x86_64) ARCH="x86_64 (64-bit)" ;;
        i*86) ARCH="x86 (32-bit)" ;;
        armv6l|armv7l) ARCH="ARM (32-bit)" ;;
        aarch64) ARCH="ARM (64-bit)" ;;
        ppc64le) ARCH="PowerPC 64-bit (little-endian)" ;;
        riscv64) ARCH="RISC-V (64-bit)" ;;
        *) ARCH="Unknown Architecture" log "Unknown architecture detected: $ARCH" WARN ;;
    esac

    log "Architecture: $ARCH" SYSTEM
}

detect_kernel() {
    log "Detecting kernel version..." INFO
    KERNEL=$(uname -r || echo "Unknown kernel")

    log "Kernel: $KERNEL" SYSTEM
}

run_detection() {
    function_tests

    log "Starting detection..." INFO

    detect_container
    detect_os
    detect_version
    detect_desktop_env
    detect_arch
    detect_kernel

    log "Detection completed." INFO

    cleanup
}

REQUIRED_COMMANDS=(
    "uname"
    "tr"
    "grep"
)

run_detection