# Universal OS Detector

Universal OS Detector is a Bash script designed to provide detailed information about the system it's running on. It aims to detect a broad range of operating systems, system architectures, kernel versions, desktop environments, and container environments, ensuring compatibility with as many systems as possible. The script is built to run effectively across different systems, providing universal detection capabilities.

## Features

- Detects operating system and version/distribution
- Identifies system architecture
- Reports kernel version
- Detects desktop environment
- Checks for container environments (Docker, Podman, Kubernetes, LXC, OpenVZ)
- Comprehensive logging with color-coded output and configurable log levels
- Error handling and cleanup procedures
- Functional tests to ensure script dependencies are met
- Supports detection on mobile including Android and iOS

## Installation

1. Clone this repository or download the `universal-os-detector.sh` script.
2. Make the script executable:
   ```
   chmod +x universal-os-detector.sh
   ```

## Usage and Examples

Run the script with:

```
./universal-os-detector.sh
```

The script provides information about:
- Container environment (if applicable)
- Operating System and Version/Distribution
- Desktop Environment
- System Architecture
- Kernel Version

### Basic Usage

When run without any options, the script outputs only the system information:

```
$ ./universal-os-detector.sh
2024-09-19 14:14:15 [system]: Not running inside a container
2024-09-19 14:14:15 [system]: Operating System: MacOS
2024-09-19 14:14:15 [system]: Version: 14.0 (Sonoma)
2024-09-19 14:14:15 [system]: Desktop Environment: MacOS
2024-09-19 14:14:15 [system]: Architecture: x86_64 (64-bit)
2024-09-19 14:14:15 [system]: Kernel: 23.6.0
```

### Configurable Log Levels

You can set the console log level using the `console_log_level` environment variable:

```
console_log_level=3 ./universal-os-detector.sh
```

Log levels:
- 0 or n/none: No console output
- 1 or d/default: system, warn, and error messages (default)
- 2 or v/verbose: system, warn, error, and info messages
- 3 or deb/debug: All messages, including debug

### Verbose Log Level Example

Here's an example of running the script with verbose logging (console_log_level=2):

```
$ console_log_level=v ./universal-os-detector.sh
2024-09-19 15:30:10 [info]: Console log level is set to: VERBOSE [2]
2024-09-19 15:30:10 [info]: Running functional tests...
2024-09-19 15:30:10 [info]: Checking command availability...
2024-09-19 15:30:10 [info]: Verifying READ/WRITE permissions for log file directory: /home/user...
2024-09-19 15:30:10 [info]: Verifying READ/WRITE permissions for log file: /home/user/universal-os-detector.log...
2024-09-19 15:30:10 [info]: All functional tests passed.
2024-09-19 15:30:10 [info]: Starting detection...
2024-09-19 15:30:10 [info]: Detecting container environment...
2024-09-19 15:30:10 [system]: Container Environment: None
2024-09-19 15:30:10 [info]: Detecting operating system...
2024-09-19 15:30:10 [system]: Operating System: Linux
2024-09-19 15:30:10 [info]: Detecting version or distribution...
2024-09-19 15:30:10 [system]: Distribution: Ubuntu 22.04 LTS
2024-09-19 15:30:10 [info]: Detecting desktop environment...
2024-09-19 15:30:10 [system]: Desktop Environment: GNOME
2024-09-19 15:30:10 [info]: Detecting architecture...
2024-09-19 15:30:10 [system]: Architecture: x86_64 (64-bit)
2024-09-19 15:30:10 [info]: Detecting kernel version...
2024-09-19 15:30:10 [system]: Kernel: 5.15.0-79-generic
2024-09-19 15:30:10 [info]: Detection completed.
2024-09-19 15:30:10 [info]: Cleaning up resources...
2024-09-19 15:30:10 [info]: Removing log file...
2024-09-19 15:30:10 [info]: Cleanup completed
2024-09-19 15:30:10 [info]: Exiting...
```

### Custom Log File

Specify a custom log file path:

```
LOG_FILE=/path/to/custom.log ./universal-os-detector.sh
```

Output is logged to the log file regardless of the console logging level. Read and write access to the directory and path of the specified log file are checked to ensure that the directory exists and the script has the necessary permissions to create and modify it.

## Integrating with Other Scripts

You can easily incorporate the Universal OS Detector into your own scripts with the following one-liner:

```bash
source <(curl -sL https://raw.githubusercontent.com/mdeacey/universal-os-detector/main/universal-os-detector.sh) && run_detection
```

Alternatively, you can use `wget`:

```bash
source <(wget -qO- https://raw.githubusercontent.com/mdeacey/universal-os-detector/main/universal-os-detector.sh) && run_detection
```

This command fetches the script from GitHub, sources it, and executes the `run_detection` function, which performs all detection operations and logs the results.

### Example: Using Detection Results in Your Script

Here's an example of how you can use the detection results in your own script:

```bash
#!/bin/bash

# Source the Universal OS Detector script
source <(curl -sL https://raw.githubusercontent.com/mdeacey/universal-os-detector/main/universal-os-detector.sh)

# Run the detection
run_detection

# Use the detection results
if [ "$os_name" = "Linux" ]; then
    echo "This is a Linux system. Running Linux-specific commands..."
    # Add your Linux-specific commands here
elif [ "$os_name" = "MacOS" ]; then
    echo "This is a MacOS system. Running MacOS-specific commands..."
    # Add your MacOS-specific commands here
elif [ "$os_name" = "Windows" ]; then
    echo "This is a Windows system. Running Windows-specific commands..."
    # Add your Windows-specific commands here
else
    echo "Unknown operating system: $os_name"
fi

# Check for specific distributions
if [ "$os_name" = "Linux" ] && [[ "$distro_name" == *"Ubuntu"* ]]; then
    echo "This is an Ubuntu system. Running Ubuntu-specific commands..."
    # Add your Ubuntu-specific commands here
fi

# Check for containerized environment
if [ "$container" = "true" ]; then
   echo "Running inside a container: $container_name"
   # Add container-specific commands here
fi

# Use other detected information
echo "System architecture: $arch"
echo "Kernel version: $kernel"
echo "Desktop environment: $desktop_env"
```

This example shows how you can use the variables set by the Universal OS Detector to make decisions in your script based on the detected system information.

## Detected Information

The script detects and provides information about the following categories. Here's a comprehensive list of all possible values for each, in comma-separated format:

1. Container Environment:
   Docker, Podman, Kubernetes, LXC, OpenVZ, Generic Container, None

2. Operating System:
   Linux, Windows, MacOS, FreeBSD, Android, iOS, Solaris, AIX, WSL, Cygwin, MinGW, Unknown

3. OS Version/Distribution:
   - Linux: Ubuntu xx.xx, Debian xx, CentOS xx, Fedora xx, Red Hat Enterprise Linux xx, Arch Linux x, Manjaro xx, openSUSE xx, Alpine Linux xx, Gentoo x, Slackware x, Linux Mint xx.xx, Elementary OS xx, Kali Linux xx, Parrot OS xx, Deepin xx, Endless OS x, Clear Linux xx, Void Linux x, MX Linux xx, Zorin OS xx, Pop!_OS xx [Other distribution names]
   - MacOS: 15.x (Sequoia), 14.x (Sonoma), 13.x (Ventura), 12.x (Monterey), 11.x (Big Sur), 10.15.x (Catalina), 10.14.x (Mojave), 10.13.x (High Sierra), 10.12.x (Sierra), 10.11.x (El Capitan), 10.10.x (Yosemite), [Older versions]
   - Windows: Windows 11, Windows 10, Windows 8.1, Windows 8, Windows 7, Windows Server 2022, Windows Server 2019, Windows Server 2016, [Older versions]
   - FreeBSD: FreeBSD xx.x, OpenBSD x.x, NetBSD x.x, [Other BSD names and versions]
   - Solaris: Oracle Solaris 11.x, Oracle Solaris 10 Update x, [Older versions]
   - Android: Android 14 (Upside Down Cake), Android 13 (Tiramisu), Android 12 (Snow Cone), Android 11 (Red Velvet Cake), [Older versions]
   - iOS: iOS 17.x, iOS 16.x, iOS 15.x, [Older versions]
   - AIX: AIX 7.3, AIX 7.2, AIX 7.1, [Older versions]

4. Desktop Environment:
   - Linux: GNOME, KDE, Xfce, MATE, Cinnamon, LXDE, LXQt, Pantheon, Enlightenment, Deepin, Budgie, Unity, i3, Awesome, Openbox, Fluxbox, GNOME Flashback, Unknown
   - Windows: WSL, Git Bash, Cygwin, PowerShell, Unknown
   - MacOS: Aqua
   - Android: Android
   - iOS: iOS
   - AIX: AIX

5. Architecture:
   x86_64 (64-bit), x86 (32-bit), ARM (32-bit), ARM (64-bit), PowerPC 64-bit (little-endian), RISC-V (64-bit), iOS (ARM), Android (ARM), AIX (PowerPC), SPARC, MIPS, Unknown

6. Kernel Version:
   Linux [version number], Darwin [version number] (for MacOS and iOS), [version number] (for Windows), FreeBSD [version number], SunOS [version number], [version number]-android[version]-[build number] (for Android), [version number] (for AIX)

## Requirements

- Bash shell
- Standard Unix utilities: uname, tr, grep

## Contributing

Contributions to improve the Universal OS Detector are welcome. Please feel free to submit pull requests or create issues for bugs and feature requests.

## License

MIT License

Copyright (c) 2024 Marcus Deacey

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Contact

Marcus Deacey
marcusdeacey@gmail.com

For issues and feature requests, please use the [GitHub Issues page](https://github.com/mdeacey/universal-os-detector/issues).
