# Universal OS Detector

Universal OS Detector is a Bash script designed to provide detailed information about the system it’s running on. It aims to detect a broad range of operating systems, system architectures, kernel versions, and container environments, ensuring compatibility with as many systems as possible. The script is built to run effectively across different systems, providing universal detection capabilities.

## Features

- Detects operating system
- Identifies system architecture
- Reports kernel version
- Checks for container environments (Docker, LXC, OpenVZ)
- Comprehensive logging with color-coded output
- Error handling and cleanup procedures

## Installation

1. Clone this repository or download the `uni_os_detect.sh` script.
2. Make the script executable:
   ```
   chmod +x uni_os_detect.sh
   ```

## Usage and Examples

Run the script with:

```
./uni_os_detect.sh
```

The script provides information about:
- Container environment (if applicable)
- Operating System
- System Architecture
- Kernel Version

### Basic Usage

When run without any options, the script outputs only the system information:

```
$ ./uni_os_detect.sh
2024-09-17 14:14:15 [SYSTEM]: Not running inside a container
2024-09-17 14:14:15 [SYSTEM]: Operating System: MacOS
2024-09-17 14:14:15 [SYSTEM]: Architecture: x86_64 (64-bit)
2024-09-17 14:14:15 [SYSTEM]: Kernel: 23.6.0
```

### Debug Mode

Enable debug mode to see detailed logging of the script's operations:

```
$ DEBUG_MODE=1 ./uni_os_detect.sh
2024-09-17 13:57:24 [INFO]: Running function tests...
2024-09-17 13:57:24 [INFO]: Checking command availability...
2024-09-17 13:57:24 [INFO]: Checking file access for: /Users/admin/uni_os_detect.log...
2024-09-17 13:57:24 [INFO]: All function tests passed.
2024-09-17 13:57:24 [INFO]: Starting detection...
2024-09-17 13:57:24 [INFO]: Detecting container environment...
2024-09-17 13:57:24 [SYSTEM]: Not running inside a container
2024-09-17 13:57:24 [INFO]: Detecting operating system...
2024-09-17 13:57:24 [SYSTEM]: Operating System: MacOS
2024-09-17 13:57:24 [INFO]: Detecting architecture...
2024-09-17 13:57:24 [SYSTEM]: Architecture: x86_64 (64-bit)
2024-09-17 13:57:24 [INFO]: Detecting kernel version...
2024-09-17 13:57:24 [SYSTEM]: Kernel: 23.6.0
2024-09-17 13:57:24 [INFO]: Detection completed.
2024-09-17 13:57:24 [INFO]: Cleaning up resources...
2024-09-17 13:57:24 [INFO]: Removing log file...
2024-09-17 13:57:24 [INFO]: Cleanup completed
2024-09-17 13:57:24 [INFO]: Exiting...
```

### Custom Log File

Specify a custom log file path:

```
LOG_FILE=/path/to/custom.log ./uni_os_detect.sh
```

Output is logged to the specified log file and, depending on the debug mode, displayed in the console with color-coded messages for different log levels.

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

## Requirements

- Bash shell
- Standard Unix utilities: uname, tr, grep

## Contributing

Contributions to improve the Universal OS Detector are welcome. Please feel free to submit pull requests or create issues for bugs and feature requests.

## License

MIT License

Copyright (c) [2024] [Marcus Deacey]

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
