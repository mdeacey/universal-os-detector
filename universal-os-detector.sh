#!/usr/bin/env bash

set -eo pipefail
trap 'log "Error encountered at line ${LINENO:-unknown} while executing command: ${BASH_COMMAND:-unknown}" "ERROR"' ERR
trap 'log "Received termination signal. Exiting." "WARN"; cleanup' SIGINT SIGTERM

#### LOGGING

log_file=${log_file:-~/universal-os-detector.log}

console_log_level=${console_log_level:-${CONSOLE_LOG_LEVEL:-1}}

color_error='\033[0;31m'
color_warn='\033[0;33m'
color_info='\033[0;30m'
color_system='\033[0;37m'
color_reset='\033[0m'
color_debug='\033[0;36m'

get_log_color() {
    local level="$1"
    case "$level" in
        error) echo "$color_error" ;;
        warn) echo "$color_warn" ;;
        info) echo "$color_info" ;;
        system) echo "$color_system" ;;
        debug) echo "$color_debug" ;;
        *) echo "$color_reset" ;;
    esac
}

print_log_message() {
    local color="$1"
    local level="$2"
    local message="$3"
    local current_time="$4"

    echo -e "${color}$current_time [$level]: $message${COLOR_RESET}"
}

lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

should_log_to_console() {
    local level="$1"
    local lower_level
    lower_level=$(lowercase "$level")

    case "$console_log_level" in
        0) return 1 ;;
        1) [[ "$lower_level" =~ ^(system|warn|error)$ ]] && return 0 || return 1 ;;
        2) [[ "$lower_level" =~ ^(system|warn|error|info)$ ]] && return 0 || return 1 ;;
        3) return 0 ;;
        *) return 1 ;;
    esac
}

log() {
    local message="${1:-}"
    local level="${2:-info}"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    local color
    color=$(get_log_color "$level")

    echo -e "$current_time [$level]: $message" >> "$log_file"

    if should_log_to_console "$level"; then
        print_log_message "$color" "$level" "$message" "$current_time"
    fi
}

#### LOGGING LEVEL VALIDATION

get_log_level() {
    local input="$1"
    local lower_case_input=$(lowercase "$input")

    if [[ "$input" =~ ^[0-3]$ ]]; then
        echo "$input"
    else
        case "$lower_case_input" in
            none|n) echo 0 ;;
            default|d) echo 1 ;;
            verbose|v) echo 2 ;;
            debug|deb) echo 3 ;;
            *) echo -1 ;;
        esac
    fi
}

get_text_log_level() {
    local level_numeric="$1"
    case "$level_numeric" in
        0) echo "NONE" ;;
        1) echo "DEFAULT" ;;
        2) echo "VERBOSE" ;;
        3) echo "DEBUG" ;;
        *) echo "UNKNOWN" ;;
    esac
}

handle_invalid_log_level_error() {
    local error_message="Error: Invalid console_log_level. Please use one of the following valid options: N/NONE/0, D/DEFAULT/1, V/VERBOSE/2, or DEB/DEBUG/3."
    echo -e "${color_error}$error_message${color_reset}" >&2
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [UNKNOWN]: $error_message" >> "$log_file"
    exit 1
}

validate_console_log_level() {
    local level_numeric
    local level_text
    local log_level_message

    level_numeric=$(get_log_level "$console_log_level")

    if [[ "$level_numeric" -eq -1 ]]; then
        handle_invalid_log_level_error
    fi

    level_text=$(get_text_log_level "$level_numeric")

    console_log_level="$level_numeric"
    log_level_message="Console log level is set to: $level_text [$console_log_level]"
    log "$log_level_message" info
}

#### FUNCTIONAL TESTS

check_command() {
    local required_command="$1"
    local version_flag="${2:---version}"
    local minimum_version="${3:-}"

    if ! command -v "$required_command" &>/dev/null; then
        log "Error: Command '$required_command' is not available." error
        return 1
    fi

    if [ -n "$minimum_version" ]; then
        current_version=$($required_command $version_flag 2>&1 | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+')
        if [ "$(printf '%s\n' "$minimum_version" "$current_version" | sort -V | head -n1)" != "$minimum_version" ]; then
            log "Error: Command '$required_command' version ($current_version) does not meet minimum version ($minimum_version)." error
            return 1
        fi
    fi
}

validate_log_file_access() {
    log "Verifying READ/WRITE permissions for log file: $log_file..." info

    if [ ! -f "$log_file" ]; then
        log "File $log_file does not exist." error
        return 1
    elif [ ! -r "$log_file" ]; then
        log "File $log_file is not readable." error
        return 1
    elif [ ! -w "$log_file" ]; then
        log "File $log_file is not writable." warn
        return 1
    fi

    return 0
}

validate_log_dir_access() {
    local log_dir=$(dirname "$log_file")
    
    log "Verifying READ/WRITE permissions for log file directory: $log_dir..." info
    
    if [ ! -d "$log_dir" ]; then
        log "Directory $log_dir does not exist." error
        return 1
    elif [ ! -r "$log_dir" ]; then
        log "Directory $log_dir is not readable." error
        return 1
    elif [ ! -w "$log_dir" ]; then
        log "Directory $log_dir is not writable." error
        return 1
    fi
    
    return 0
}

functional_tests() {
    log "Running functional tests..." info

    log "Checking command availability..." info
    check_command "uname" || exit 1
    check_command "tr" || exit 1
    check_command "grep" || exit 1

    validate_log_dir_access || exit 1
    validate_log_file_access || exit 1

    log "All functional tests passed." info
}

#### MAIN DETECTION LOGIC

#### CONTAINER

detect_container() {
    log "Detecting container environment..." info

    if [ -f /.dockerenv ]; then
        container="Docker"
    elif grep -q 'libpod' /proc/1/cgroup 2>/dev/null; then
        container="Podman"
    elif grep -q '/kubepods' /proc/1/cgroup 2>/dev/null; then
        container="Kubernetes"
    elif grep -q 'lxc' /proc/1/cgroup 2>/dev/null; then
        container="LXC"
    elif grep -q 'VxID' /proc/self/status 2>/dev/null; then
        container="OpenVZ"
    elif grep -q 'docker\|containerd\|lxc' /proc/1/cgroup 2>/dev/null; then
        container="Generic Container"
    else
        container="None"
    fi

    if [ "$container" != "None" ]; then
        log "Container Environment: $container" system
    else
        log "Container Environment: None" system
    fi
}

#### OS

detect_os() {
    log "Detecting operating system..." info
    os=""
    
    os_detection_functions=("detect_linux_os" "detect_windows_os" "detect_macos_os" "detect_freebsd_os" 
                             "detect_android_os" "detect_ios_os" "detect_solaris_os" "detect_aix_os")
    
    for detect_fn in "${os_detection_functions[@]}"; do
        if $detect_fn; then
            log "Operating System: $os" system
            return
        fi
    done

    log "OS detection failed, no known OS detected" warn
    os="Unknown"
    log "Operating System: ${os:-Unknown}" system
}

detect_linux_os() {
    if [[ "$(uname -s)" == "Linux" ]] || 
       grep -qi "linux" /proc/version 2>/dev/null || 
       [[ "$(cat /proc/sys/kernel/ostype 2>/dev/null)" == "Linux" ]] || 
       [[ -d /sys/module ]]; then
        os="Linux"
        return 0
    fi
    return 1
}

detect_windows_os() {
    if [[ "$(uname -s)" == *"NT"* ]] || 
       [[ -n "$WINDIR" ]] || 
       grep -qi microsoft /proc/version 2>/dev/null; then
        os="Windows"
        return 0
    elif [[ "$(uname -r)" == *"WSL"* ]] || 
         [[ -f "/proc/version" && $(grep -qi 'wsl' /proc/version) ]]; then
        os="WSL"
        return 0
    elif [[ "$(uname -s)" == *"CYGWIN"* ]] || 
         [[ -f "/proc/version" && $(grep -qi 'cygwin' /proc/version) ]]; then
        os="Cygwin"
        return 0
    elif [[ "$(uname -s)" == *"MINGW"* ]] || 
         [[ -f "/proc/version" && $(grep -qi 'mingw' /proc/version) ]]; then
        os="MinGW"
        return 0
    fi
    return 1
}

detect_macos_os() {
    if [[ "$(uname)" == "Darwin" ]] || 
       [[ -d /System/Library/CoreServices ]] || 
       [[ -f /System/Library/CoreServices/SystemVersion.plist ]]; then
        os="MacOS"
        return 0
    fi
    return 1
}

detect_freebsd_os() {
    if [[ "$(uname -s)" == "FreeBSD" ]] || 
       [[ -f /bin/freebsd-version ]] || 
       [[ -d /boot/kernel ]]; then
        os="FreeBSD"
        return 0
    fi
    return 1
}

detect_android_os() {
    if [[ "$(uname -o 2>/dev/null)" == "Android" ]] || 
       [[ -f "/system/build.prop" || -f "/data/system/packages.xml" ]] || 
       [[ -d "/system" && -d "/data" ]] || 
       [[ "$(getprop ro.build.version.release 2>/dev/null)" ]]; then
        os="Android"
        return 0
    fi
    return 1
}

detect_ios_os() {
    if [[ "$(uname -s)" == "Darwin" && -d "/var/mobile" ]] || 
       [[ -f "/System/Library/CoreServices/SystemVersion.plist" ]] || 
       [[ -f "/usr/bin/ideviceinfo" ]]; then
        os="iOS"
        return 0
    fi
    return 1
}

detect_solaris_os() {
    if [[ "$(uname -s)" == "SunOS" ]] || 
       [[ -d "/usr/sbin" && -d "/usr/bin" ]] || 
       [[ -f "/etc/release" ]]; then
        os="Solaris"
        return 0
    fi
    return 1
}

detect_aix_os() {
    if [[ "$(uname -s)" == "AIX" ]] || 
       [[ -f "/etc/os-release" && $(grep -qi "aix" /etc/os-release) ]] || 
       [[ -f "/etc/vmlinux" ]]; then
        os="AIX"
        return 0
    fi
    return 1
}

#### VERSION

detect_version() {
    log "Detecting version or distribution..." info

    case "$os" in
        MacOS)
            detect_macos_version
            ;;
        Linux)
            detect_linux_version
            ;;
        Windows)
            detect_windows_version
            ;;
        FreeBSD)
            detect_freebsd_version
            ;;
        Solaris)
            detect_solaris_version
            ;;
        Android)
            detect_android_version
            ;;
        iOS)
            detect_ios_version
            ;;
        AIX)
            detect_aix_version
            ;;
        *)
            log "No version name available for $os" info
            ;;
    esac
}

detect_macos_version() {
    if command -v sw_vers &>/dev/null; then
        macos_version=$(sw_vers -productVersion)
        macos_name=$(sw_vers -productName)
        case "$macos_version" in
            15.*) macos_name="Sequoia" ;;
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
                log "Unknown MacOS version: $macos_version" warn
                ;;
        esac
        log "Version: $macos_version ($macos_name)" system
    else
        log "Command 'sw_vers' not found. Unable to detect MacOS version." error
    fi
}

detect_linux_version() {
    if [ -f /etc/os-release ]; then
        distro_name=$(grep '^NAME=' /etc/os-release | cut -d '"' -f 2)
        distro_version=$(grep '^VERSION=' /etc/os-release | cut -d '"' -f 2)
        distro_info="$distro_name $distro_version"
    elif command -v lsb_release &>/dev/null; then
        distro_name=$(lsb_release -si)
        distro_version=$(lsb_release -sr)
        distro_info="$distro_name $distro_version"
    elif [ -f /etc/redhat-release ]; then
        distro_info=$(cat /etc/redhat-release)
    elif [ -f /etc/debian_version ]; then
        distro_info="Debian $(cat /etc/debian_version)"
    else
        distro_info="Unknown Linux distribution"
        log "Unknown Linux distribution, /etc/os-release or lsb_release not found." warn
    fi
    log "Distribution: $distro_info" system
}

detect_windows_version() {
    if command -v powershell.exe &>/dev/null; then
        win_name=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).Caption" | tr -d '\r')
        win_version=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).Version" | tr -d '\r')
        win_build=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).BuildNumber" | tr -d '\r')
        if [ -z "$win_name" ] || [ -z "$win_version" ]; then
            win_info="Unknown Windows version"
            log "Unable to fully retrieve Windows version info" warn
        else
            win_info="$win_name (Version: $win_version, Build: $win_build)"
        fi
    elif command -v wmic &>/dev/null; then
        win_info=$(wmic os get Caption, Version /format:table | sed -n 2p)
    elif command -v cmd.exe &>/dev/null; then
        win_info=$(cmd.exe /c ver | tr -d '\r')
    else
        win_info="Unknown Windows version"
        log "No available method to detect Windows version." warn
    fi
    log "Windows Version: $win_info" system
}

detect_freebsd_version() {
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
        log "Unable to detect BSD version, /etc/os-release or uname missing." warn
    fi
    log "BSD Version: $bsd_info" system
}

detect_solaris_version() {
    if [ -f /etc/release ]; then
        sol_version=$(grep '^Oracle Solaris' /etc/release | cut -d ':' -f 2 | xargs)
        sol_info="Oracle Solaris $sol_version"
    elif command -v uname &>/dev/null; then
        sol_info="Solaris $(uname -r)"
    else
        sol_info="Unknown Solaris version"
        log "Unable to detect Solaris version" warn
    fi
    log "Solaris Version: $sol_info" system
}

detect_android_version() {
    if command -v getprop &>/dev/null; then
        android_version=$(getprop ro.build.version.release)
        android_codename=$(getprop ro.build.version.codename)
        android_device=$(getprop ro.product.model)
        if [[ -z "$android_version" ]]; then
            log "Unknown Android version" warn
        else
            log "Android Version: $android_version ($android_codename), Device: $android_device" system
        fi
    else
        log "Command 'getprop' not found. Unable to detect Android version." error
    fi
}

detect_ios_version() {
    if command -v ideviceinfo &>/dev/null; then
        ios_version=$(ideviceinfo -k ProductVersion)
        ios_device=$(ideviceinfo -k ProductType)
        ios_name="iOS"
        if [[ -z "$ios_version" ]]; then
            log "Unknown iOS version" warn
        else
            log "iOS Version: $ios_version, Device: $ios_device" system
        fi
    else
        log "Command 'ideviceinfo' not found. Unable to detect iOS version." error
    fi
}

detect_aix_version() {
    if command -v oslevel &>/dev/null; then
        aix_version=$(oslevel)
        if [[ -z "$aix_version" ]]; then
            log "Unknown AIX version" warn
        else
            log "AIX Version: $aix_version" system
        fi
    else
        log "Command 'oslevel' not found. Unable to detect AIX version." error
    fi
}

#### DESKTOP ENV

detect_desktop_env() {
    log "Detecting desktop environment..." info
    local desktop_env="Unknown desktop environment"

    if [ "$os" = "Linux" ]; then
        if [ -n "$xdg_current_desktop" ]; then
            desktop_env="$xdg_current_desktop"
        elif [ -n "$desktop_session" ]; then
            desktop_env="$desktop_session"
        elif [ -n "$gdm_session" ]; then
            desktop_env="$gdm_session"
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
                log "No known desktop Linux environment binaries found." warn
            fi
        fi
    elif [ "$os" = "Windows" ]; then
        if grep -qi microsoft /proc/version 2>/dev/null; then
            desktop_env="WSL (Windows Subsystem for Linux)"
        elif [[ "$ostype" == "msys"* ]]; then
            desktop_env="Git Bash"
        elif [[ "$ostype" == "cygwin"* ]]; then
            desktop_env="Cygwin"
        elif command -v powershell.exe &>/dev/null; then
            desktop_env="PowerShell"
        else
            desktop_env="Command Prompt (or unknown Windows shell)"
        fi
    elif [ "$os" = "MacOS" ]; then
        desktop_env="MacOS"
    else
        log "Unsupported operating system: $os" error
    fi

    log "Desktop Environment: $desktop_env" system
}

#### ARCH

detect_arch() {
    log "Detecting architecture..." info
    arch=$(uname -m || echo "Unknown architecture")

    case "$arch" in
        x86_64) arch="x86_64 (64-bit)" ;;
        i*86) arch="x86 (32-bit)" ;;
        armv6l|armv7l) arch="ARM (32-bit)" ;;
        aarch64) arch="ARM (64-bit)" ;;
        ppc64le) arch="PowerPC 64-bit (little-endian)" ;;
        riscv64) arch="RISC-V (64-bit)" ;;
        *) arch="Unknown Architecture" log "Unknown architecture detected: $arch" warn ;;
    esac

    log "Architecture: $arch" system
}

#### KERNEL

detect_kernel() {
    log "Detecting kernel version..." info
    kernel=$(uname -r || echo "Unknown kernel")

    log "Kernel: $kernel" system
}

#### CLEANUP

cleanup() {
    log "Cleaning up resources..." info
    log "Removing log file..." info
    rm -f "$log_file".lock
    log "Cleanup completed" info
    log "Exiting..." info
    exit 0
}


#### MAIN

run_detection() {
    validate_console_log_level

    functional_tests

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

run_detection