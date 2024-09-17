# Creating a Universal OS Detection Script: Solving a Common Developer Challenge
Linkedin article link: https://www.linkedin.com/pulse/creating-universal-os-detection-script-solving-common-marcus-deacey-6sbcc/

## Introduction

As developers, we often face the challenge of creating scripts that need to work across multiple operating systems. One of the most common tasks is detecting the OS on which a script is running. While there are many solutions available online, most are incomplete or tailored to specific use cases. This article explores the creation of a universal OS detection script that addresses these limitations and provides a robust solution for developers.

## The Problem

A quick search for "bash detect OS" on Stack Overflow reveals a popular question with over 800 upvotes and 500,000 views. The answers provide various methods, but none offer a comprehensive solution that works universally across different environments. This fragmentation leads to developers cobbling together different approaches, often resulting in scripts that are brittle or fail in edge cases.

## The Solution: A Universal OS Detection Script

To address this common challenge, we've created a comprehensive Bash script that not only detects the operating system but also provides additional useful information about the environment. Let's break down the key components of this script:

1. **Robust Error Handling**: The script uses `set -eo pipefail` and trap commands to catch and report errors, ensuring that issues are not silently ignored.

```bash
set -eo pipefail
trap 'log "Error encountered at line ${LINENO:-unknown} while executing command: ${BASH_COMMAND:-unknown}" "ERROR"' ERR
```

2. **Comprehensive Logging**: A flexible logging system is implemented, allowing for different log levels (ERROR, WARN, INFO, SYSTEM, DEBUG) and optional debug output.

```bash
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
        DEBUG) color=$COLOR_RESET ;;
        *) color=$COLOR_RESET ;;
    esac

    echo -e "$current_time [$level]: $message" >> "$LOG_FILE"

    if [ "$DEBUG_MODE" -eq 1 ] || [ "$level" = "SYSTEM" ] || [ "$level" = "ERROR" ]; then
        echo -e "${color}$current_time [$level]: $message${COLOR_RESET}"
    fi
}
```

3. **Container Detection**: The script checks for common indicators of containerized environments, such as Docker or LXC.

```bash
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
```

4. **OS Detection**: Using a combination of `uname` and `$OSTYPE`, the script can accurately identify a wide range of operating systems, including macOS, Linux, FreeBSD, Windows (via Cygwin/MSYS), Solaris, and AIX.

```bash
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
```

5. **Architecture Detection**: The script identifies the system architecture, covering common types like x86, ARM, PowerPC, and RISC-V.

```bash
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
```

6. **Kernel Version**: For Unix-like systems, the kernel version is also reported.

```bash
detect_kernel() {
    log "Detecting kernel version..." INFO
    KERNEL=$(uname -r || echo "Unknown kernel")
    log "Kernel: $KERNEL" SYSTEM
}
```

7. **Function Tests**: Before running the main detection routines, the script checks for the availability of required commands and file access permissions.

```bash
function_tests() {
    log "Running function tests..." INFO
    log "Checking command availability..." INFO
    check_command "uname" || exit 1
    check_command "tr" || exit 1
    check_command "grep" || exit 1
    check_file_access "$LOG_FILE" || exit 1
    log "All function tests passed." INFO
}
```

8. **Cleanup Routine**: A cleanup function ensures that temporary resources are properly removed upon script completion or interruption.

```bash
cleanup() {
    log "Cleaning up resources..." INFO
    log "Removing log file..." INFO
    rm -f "$LOG_FILE".lock
    log "Cleanup completed" INFO
    log "Exiting..." INFO
    exit 0
}

trap 'log "Received termination signal. Exiting." "WARN"; cleanup' SIGINT SIGTERM
```

## Key Features and Best Practices

1. **Portability**: The script uses POSIX-compliant commands and syntax, ensuring it works across different Unix-like systems.

2. **Security**: The script avoids using `eval` or other potentially dangerous constructs, prioritizing security.

3. **Flexibility**: Environment variables like `LOG_FILE` and `DEBUG_MODE` allow users to customize the script's behavior without modifying the code.

```bash
LOG_FILE=${LOG_FILE:-~/universal-os-detector.log}
DEBUG_MODE=${DEBUG_MODE:-0}
```

4. **Comprehensive Detection**: By checking multiple system attributes, the script provides a more complete picture of the environment than simpler OS detection methods.

5. **Error Resilience**: The script includes error checking and reporting, making it easier to diagnose issues when they occur.

## Conclusion

Creating a universal OS detection script addresses a common need in the developer community. By providing a comprehensive, robust, and flexible solution, we can save time and reduce errors in cross-platform development workflows. This script serves as a foundation that can be easily integrated into larger projects or used as a standalone tool for system information gathering.

As the development landscape continues to evolve, with new operating systems and containerized environments emerging, having a reliable method for OS detection becomes increasingly crucial. This script aims to be that reliable tool, adaptable to future changes while solving today's challenges.

The full script, along with documentation and usage instructions, is available on GitHub:

[Universal OS Detector](https://github.com/mdeacey/universal-os-detector/tree/main)

Feel free to use, modify, and contribute to this script. I encourage you to explore the repository, test the script in your own environments, and share your feedback. Your contributions can help enhance the tool and make it more robust for the entire development community. Together, we can build more reliable solutions for cross-platform development.
