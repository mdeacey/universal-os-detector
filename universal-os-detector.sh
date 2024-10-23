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

uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
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

    local upper_level
    upper_level=$(uppercase "$level")

    echo -e "$current_time [$upper_level]: $message" >> "$log_file"

    if should_log_to_console "$level"; then
        print_log_message "$color" "$upper_level" "$message" "$current_time"
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

    container=false
    container_name="None"

    if [ -f /.dockerenv ]; then
        container_name="Docker"
    elif grep -q 'libpod' /proc/1/cgroup 2>/dev/null; then
        container_name="Podman"
    elif grep -q '/kubepods' /proc/1/cgroup 2>/dev/null; then
        container_name="Kubernetes"
    elif grep -q 'lxc' /proc/1/cgroup 2>/dev/null; then
        container_name="LXC"
    elif grep -q 'VxID' /proc/self/status 2>/dev/null; then
        container_name="OpenVZ"
    elif grep -q 'docker\|containerd\|lxc' /proc/1/cgroup 2>/dev/null; then
        container_name="Generic Container"
    fi

    [ "$container_name" != "None" ] && container=true

    log "Container Environment: $container_name" system
}

#### OS

detect_os() {
    log "Detecting operating system..." info
    os_name=""

    uname_str=$(uname -s)
    
    case "$uname_str" in
        Linux)          os_name="Linux" ;;
        Darwin)         os_name="MacOS" ;;
        FreeBSD)        os_name="FreeBSD" ;;
        OpenBSD)        os_name="OpenBSD" ;;
        NetBSD)         os_name="NetBSD" ;;
        DragonFlyBSD)   os_name="DragonFlyBSD" ;;
        SunOS)          os_name="Solaris" ;;
        AIX)            os_name="AIX" ;;
        *)              log "Quick check did not detect a known OS, running detailed checks..." info ;;
    esac

    if [[ -n "$os_name" ]]; then
        log "Operating System: $os_name" system
        return
    fi

    if detect_linux_os || detect_windows_os || detect_macos_os || 
       detect_freebsd_os || detect_android_os || detect_ios_os || 
       detect_solaris_os || detect_aix_os || detect_freebsd_os || 
       detect_openbsd_os || detect_netbsd_os || detect_dragonflybsd_os; then
        log "Operating System: $os_name" system
    else
        log "Unable to detect OS." warn
        os_name="Unknown"
        log "Operating System: $os_name" system
    fi
}

detect_linux_os() {
    if grep -qi "linux" /proc/version 2>/dev/null || 
       [[ "$(cat /proc/sys/kernel/ostype 2>/dev/null)" == "Linux" ]] || 
       [[ -d /sys/module ]]; then
        os_name="Linux"
        return 0
    fi
    return 1
}

detect_windows_os() {
    if [[ -n "$WINDIR" ]] || 
       grep -qi microsoft /proc/version 2>/dev/null; then
        os_name="Windows"
        return 0
    elif [[ -f "/proc/version" && $(grep -qi 'wsl' /proc/version) ]]; then
        os_name="WSL"
        return 0
    elif [[ -f "/proc/version" && $(grep -qi 'cygwin' /proc/version) ]]; then
        os_name="Cygwin"
        return 0
    elif [[ -f "/proc/version" && $(grep -qi 'mingw' /proc/version) ]]; then
        os_name="MinGW"
        return 0
    fi
    return 1
}

detect_macos_os() {
    if [[ -d /System/Library/CoreServices ]] || 
       [[ -f /System/Library/CoreServices/SystemVersion.plist ]]; then
        os_name="MacOS"
        return 0
    fi
    return 1
}

detect_android_os() {
    if [[ -f "/system/build.prop" || -f "/data/system/packages.xml" ]] || 
       [[ -d "/system" && -d "/data" ]] || 
       [[ "$(getprop ro.build.version.release 2>/dev/null)" ]]; then
        os_name="Android"
        return 0
    fi
    return 1
}

detect_ios_os() {
    if [[ -d "/var/mobile" ]] || 
       [[ -f "/System/Library/CoreServices/SystemVersion.plist" ]] || 
       [[ -f "/usr/bin/ideviceinfo" ]]; then
        os_name="iOS"
        return 0
    fi
    return 1
}

detect_solaris_os() {
    if [[ -d "/usr/sbin" && -d "/usr/bin" ]] || 
       [[ -f "/etc/release" ]]; then
        os_name="Solaris"
        return 0
    fi
    return 1
}

detect_aix_os() {
    if [[ -f "/etc/os-release" && $(grep -qi "aix" /etc/os-release) ]] || 
       [[ -f "/etc/vmlinux" ]]; then
        os_name="AIX"
        return 0
    fi
    return 1
}

detect_freebsd_os() {
    if [[ -f /bin/freebsd-version ]] || [[ -d /boot/kernel ]]; then
        os_name="FreeBSD"
        return 0
    fi
    return 1
}

detect_openbsd_os() {
    if [[ -f /etc/version ]]; then
        os_name="OpenBSD"
        return 0
    fi
    return 1
}

detect_netbsd_os() {
    if [[ -f /etc/netbsd-version ]]; then
        os_name="NetBSD"
        return 0
    fi
    return 1
}

detect_dragonflybsd_os() {
    if [[ -f /bin/dfbsd-version ]]; then
        os_name="DragonFlyBSD"
        return 0
    fi
    return 1
}

### DIST

detect_linux_dist() {
    log "Detecting Linux distribution..." info
    if [ -f /etc/os-release ]; then
        linux_distro_name=$(grep '^NAME=' /etc/os-release | cut -d '"' -f 2)
    elif command -v lsb_release &>/dev/null; then
        linux_distro_name=$(lsb_release -si)
    else
        linux_distro_name="Unknown"
        log "Unable to detect Linux Distribution name." warn
    fi
    log "Linux Distribution Name: $linux_distro_name" system
}

### VERSION NUMBER

detect_version_number() {
    log "Detecting version number..." info

    case "$os_name" in
        MacOS)          detect_macos_ver_no ;;
        # Linux)        Base on detect_linux_dist TBA ;;
        Windows)        detect_windows_ver_no ;;
        WSL)            detect_wsl_ver_no ;;
        Cygwin)         detect_cygwin_ver_no ;;
        MinGW)          detect_mingw_ver_no ;;
        FreeBSD)        detect_freebsd_ver_no ;;
        OpenBSD)        detect_openbsd_ver_no ;;
        NetBSD)         detect_netbsd_ver_no ;;
        DragonflyBSD)   detect_dragonflybsd_ver_no ;;
        Solaris)        detect_solaris_ver_no ;;
        Android)        detect_android_ver_no ;;
        iOS)            detect_ios_ver_no ;;
        AIX)            detect_aix_ver_no ;;
        *)              log "Unable to detect version number for $os_name" info ;;
    esac
}

detect_macos_ver_no() {
    version_number=$(sw_vers -productVersion 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_linux_ver_no() {
    if [ -f /etc/os-release ]; then
        version_number=$(grep -oP '^VERSION="\K[^"]+' /etc/os-release)
    elif command -v lsb_release &>/dev/null; then
        version_number=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        version_number=$(< /etc/redhat-release)
    elif [ -f /etc/debian_version ]; then
        version_number="Debian $(< /etc/debian_version)"
    fi
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_windows_ver_no() {
    version_number=$(powershell.exe -Command "(Get-WmiObject -Class Win32_OperatingSystem).Version" 2>/dev/null || 
    wmic os get Version | sed -n 2p || 
    cmd.exe /c ver)
    version_number=$(echo "$version_number" | tr -d '\r')
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_freebsd_ver_no() {
    version_number=$(grep -oP '^VERSION="\K[^"]+' /etc/os-release 2>/dev/null || 
    sysctl -n kern.version 2>/dev/null || 
    uname -r)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_openbsd_ver_no() {
    version_number=$(uname -r || 
    dmesg | grep -oP 'OpenBSD \K[0-9]+\.[0-9]+' | head -n 1 || 
    sysctl -n kern.version 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_netbsd_ver_no() {
    version_number=$(uname -r || 
    sysctl -n kern.version 2>/dev/null || 
    dmesg | grep -oP 'NetBSD \K[0-9]+\.[0-9]+' | head -n 1)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_dragonflybsd_ver_no() {
    version_number=$(uname -r || 
    dmesg | grep -oP 'DragonFly v\K[0-9]+\.[0-9]+' | head -n 1 || 
    sysctl -n kern.version 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_wsl_ver_no() {
    version_number=$(wsl.exe --version 2>/dev/null | grep -oP 'WSL \K[0-9]+(\.[0-9]+)?' || 
    uname -r | grep -oP 'Microsoft \K[0-9]+\.[0-9]+' || 
    powershell.exe -Command "[System.Environment]::OSVersion.Version" 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_cygwin_ver_no() {
    version_number=$(cygcheck -V 2>/dev/null | grep -oP 'Cygwin \K[0-9]+\.[0-9]+' || 
                     uname -r | grep -oP 'cygwin \K[0-9]+\.[0-9]+' || 
                     setup-x86.exe --version 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_mingw_ver_no() {
    version_number=$(gcc --version 2>/dev/null | grep -oP 'gcc \(MinGW\) \K[0-9]+\.[0-9]+' || 
                    mingw-get --version 2>/dev/null | grep -oP 'MinGW \K[0-9]+\.[0-9]+' || 
                    uname -r | grep -oP 'mingw-w64 \K[0-9]+\.[0-9]+')
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_solaris_ver_no() {
    version_number=$(grep -oP '^Oracle Solaris.*:\K.*' /etc/release 2>/dev/null || uname -r)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_android_ver_no() {
    version_number=$(getprop ro.build.version.release 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_ios_ver_no() {
    version_number=$(ideviceinfo -k ProductVersion 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}

detect_aix_ver_no() {
    version_number=$(oslevel 2>/dev/null)
    [ -n "$version_number" ] && log "Version Number: $version_number" system || 
    log "Unable to detect version number." warn
}


### VERSION NAME

detect_version_name() {
    log "Detecting version name..." info

    case "$os_name" in
        MacOS)          map_macos_ver_name ;;
        # Linux)        Need to detect Distribution first, fix TBA ;;
        Windows)        map_win_ver_name ;;
        # WSL)          TBA ;;
        # Cygwin)       TBA ;;
        # MinGW)        TBA ;;
        # FreeBSD)      TBA ;;
        # OpenBSD)      TBA ;;
        # NetBSD)       TBA ;;
        # DragonflyBSD) TBA ;;
        Solaris)        map_solaris_ver_name ;;
        Android)        map_android_ver_name ;;
        # iOS)          Numbers only fix TBA ;;
        # AIX)          Numbers only fix TBA ;;
        *)              log "No version name available for $os_name" info ;;
    esac
}

map_macos_ver_name() {
    case "$version_number" in
        15.*) version_name="Sequoia" ;;
        14.*) version_name="Sonoma" ;;
        13.*) version_name="Ventura" ;;
        12.*) version_name="Monterey" ;;
        11.*) version_name="Big Sur" ;;
        10.15*) version_name="Catalina" ;;
        10.14*) version_name="Mojave" ;;
        10.13*) version_name="High Sierra" ;;
        10.12*) version_name="Sierra" ;;
        10.11*) version_name="El Capitan" ;;
        10.10*) version_name="Yosemite" ;;
        *) 
            version_name="Unknown"
            log "Unable to map version number to version name." warn
            ;;
    esac
    log "Version Name: $version_name" system
}

map_win_ver_name() {
    case "$version_number" in
        11.0.*) version_name="Windows 11" ;;
        10.0.*) version_name="Windows 10" ;;
        6.3.*) version_name="Windows 8.1" ;;
        6.2.*) version_name="Windows 8" ;;
        6.1.*) version_name="Windows 7" ;;
        6.0.*) version_name="Windows Vista" ;;
        5.1.*) version_name="Windows XP" ;;
        5.0.*) version_name="Windows 2000" ;;
        4.0.*) version_name="Windows NT 4.0" ;;
        3.51.*) version_name="Windows NT 3.51" ;;
        3.5.*) version_name="Windows NT 3.5" ;;
        3.1.*) version_name="Windows 3.1" ;;
        2.0.*) version_name="Windows 2.0" ;;
        1.0.*) version_name="Windows 1.0" ;;
        *) 
            version_name="Unknown"
            log "Unable to map version number to version name." warn
            ;;
    esac
    log "Version Name: $version_name" system
}

map_solaris_ver_name() {
    case "$version_number" in
        11.*) version_name="Oracle Solaris 11" ;;
        10.*) version_name="Oracle Solaris 10" ;;
        5.11) version_name="SunOS 5.11" ;;
        5.10) version_name="SunOS 5.10" ;;
        5.9)  version_name="SunOS 5.9" ;;
        5.8)  version_name="SunOS 5.8" ;;
        *) 
            version_name="Unknown"
            log "Unable to map version number to version name." warn
            ;;
    esac
    log "Version Name: $version_name" system
}

map_android_ver_name() {
    case "$version_number" in
        14.*) version_name="Upside Down Cake" ;;
        13.*) version_name="Tiramisu" ;;
        12.*) version_name="Snow Cone" ;;
        11.*) version_name="Red Velvet Cake" ;;
        10.*) version_name="Quince Tart" ;;
        9.*)  version_name="Pie" ;;
        8.*)  version_name="Oreo" ;;
        7.*)  version_name="Nougat" ;;
        6.*)  version_name="Marshmallow" ;;
        5.*)  version_name="Lollipop" ;;
        4.4*) version_name="KitKat" ;;
        4.3*) version_name="Jelly Bean" ;;
        4.2*) version_name="Jelly Bean" ;;
        4.1*) version_name="Jelly Bean" ;;
        4.0*) version_name="Ice Cream Sandwich" ;;
        3.*)  version_name="Honeycomb" ;;
        2.3*) version_name="Gingerbread" ;;
        2.2*) version_name="FroYo" ;;
        2.1*) version_name="Eclair" ;;
        1.6)  version_name="Donut" ;;
        1.5)  version_name="Cupcake" ;;
        *) 
            version_name="Unknown"
            log "Unable to map version number to version name." warn
            ;;
    esac
    log "Version Name: $version_name" system
}


#### DESKTOP ENV

detect_desktop_env() {
    log "Detecting desktop environment..." info

    case "$os_name" in
        Linux)
            detect_linux_desktop_env
            ;;
        Windows)
            detect_windows_desktop_env
            ;;
        MacOS|Android|iOS|AIX)
            log "Desktop Environment: $os_name" system
            ;;
        *)
            log "Unsupported operating system: $os_name" error
            ;;
    esac
}

detect_linux_desktop_env() {
    local desktop_env="Unknown Linux desktop environment"

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
            log "No known Linux desktop environment binaries found." warn
        fi
    fi
    log "Linux Desktop Environment: $desktop_env" system
}

detect_windows_desktop_env() {
    local desktop_env="Unknown Windows desktop environment"

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

    log "Windows Desktop Environment: $desktop_env" system
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
        arm*)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                arch="iOS (ARM)"
            else
                arch="Android (ARM)"
            fi ;;
        rs6000) arch="AIX (PowerPC)" ;;
        *) arch="Unknown Architecture" 
           log "Unknown architecture detected: $arch" warn ;;
    esac

    log "Architecture: $arch" system
}

#### KERNEL

detect_kernel() {
    log "Detecting kernel version..." info

    kernel=$(uname -r || echo "Unknown kernel")

    if [[ "$OSTYPE" == "android"* ]]; then
        kernel_fallback=$(getprop | grep "ro.build.version.release" | awk -F "=" '{print $2}')
        kernel=${kernel:-$kernel_fallback}
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        kernel_fallback=$(uname -v)
        kernel=${kernel:-$kernel_fallback}
    fi

    log "Kernel: $kernel" system
}

#### CLEANUP

cleanup() {
    log "Cleaning up resources..." info
    log "Removing log file..." info
    rm -f "$log_file".lock
    log "Cleanup completed" info
}

#### MAIN

run_detection() {
    validate_console_log_level

    functional_tests

    log "Starting detection..." INFO

    detect_container
    detect_os

    if [[ "$os_name" == "Linux" ]]; then
        detect_linux_dist
    fi

    detect_version_number
    detect_version_name
    detect_desktop_env
    detect_arch
    detect_kernel

    log "Detection completed." INFO

    cleanup
}

run_detection
log "Exiting..." info