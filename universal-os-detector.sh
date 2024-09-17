#!/bin/bash

set -eo pipefail
trap 'log "Error encountered at line ${LINENO:-unknown} while executing command: ${BASH_COMMAND:-unknown}" "ERROR"' ERR

LOG_FILE=${LOG_FILE:-~/uni_os_detect.log}
DEBUG_MODE=${DEBUG_MODE:-0}

# Define colors for log levels
COLOR_ERROR='\033[0;31m'   # Red
COLOR_WARN='\033[0;33m'    # Yellow
COLOR_INFO='\033[0;30m'    # Grey
COLOR_SYSTEM='\033[0;37m'  # White
COLOR_RESET='\033[0m'      # Reset to default color

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
        ERROR) color=$COLOR_ERROR ;;
        WARN) color=$COLOR_WARN ;;
        INFO) color=$COLOR_INFO ;;
        SYSTEM) color=$COLOR_SYSTEM ;;
        DEBUG) color=$COLOR_RESET ;;  # DEBUG messages are not colored
        *) color=$COLOR_RESET ;;
    esac

    echo -e "$current_time [$level]: $message" >> "$LOG_FILE"

    # Output to console based on DEBUG_MODE
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

function_tests() {
    log "Running function tests..." INFO
    log "Checking command availability..." INFO
    check_command "uname" || exit 1
    check_command "tr" || exit 1
    check_command "grep" || exit 1
    check_file_access "$LOG_FILE" || exit 1
    log "All function tests passed." INFO
}

REQUIRED_COMMANDS=(
    "uname"
    "tr"
    "grep"
)

# Run function tests only once
function_tests

log "Starting detection..." INFO

detect_container
detect_os
detect_arch
detect_kernel

log "Detection completed." INFO

cleanup
