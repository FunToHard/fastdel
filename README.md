# FastDel 🚀

## ⚖️ DISCLAIMER AND LIMITATION OF LIABILITY

**⚠️ IMPORTANT: READ CAREFULLY BEFORE USING THIS SOFTWARE ⚠️**

FastDel is a powerful file deletion tool provided "AS IS" without any warranties or guarantees. By using this software, you acknowledge and agree to the following:

### No Liability for Data Loss
The author(s) and contributor(s) of FastDel **SHALL NOT BE LIABLE** for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.

### User Responsibility
- **YOU ARE SOLELY RESPONSIBLE** for verifying the correctness of the target path before deletion
- **YOU ASSUME ALL RISKS** associated with the use of this software
- The software permanently deletes files and directories, and **RECOVERY MAY NOT BE POSSIBLE**
- Always ensure you have proper backups before using this tool
- Test the software in a safe environment before using it on important data

### No Warranty
This software is provided without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement.

### Release of Claims
By using FastDel, you agree to release, discharge, and hold harmless the author(s) and contributor(s) from any and all claims, demands, damages, actions, or causes of action arising out of or related to the use of this software.

---

A high-performance directory deletion tool written in Rust, specifically optimized for large directories like `node_modules` that contain thousands of small files and deeply nested folder structures.

## Features

- **⚡ Lightning Fast**: Optimized for deleting directories with thousands of small files
- **🔄 Concurrent Operations**: Uses async/await for maximum performance
- **📏 Long Path Support**: Handles Windows long path names (>260 characters)
- **📊 Progress Tracking**: Visual feedback and detailed statistics
- **🛡️ Safe & Reliable**: Confirmation prompts and graceful error handling
- **💾 Memory Efficient**: Recursive traversal without excessive memory usage
- **🎯 Self-Documenting**: Clean, maintainable code that explains what it's doing

## Why FastDel?

Traditional deletion tools can be extremely slow when dealing with directories like `node_modules` that contain:
- Thousands of small files
- Deeply nested directory structures surpassing path limits of 260
- Very long file paths (especially on Windows)

FastDel is specifically designed to handle these scenarios efficiently by:
- Using asynchronous I/O operations
- Processing files and directories concurrently
- Minimizing system call overhead
- Handling Windows long path limitations

## Quick Demo with Docker

The easiest way to try FastDel is using our Docker demo:

### Prerequisites
- Docker installed and running
- Docker Compose (included with Docker Desktop)

### Run the Demo

**Windows:**
```cmd
.\run-demo.bat
```

**Linux/macOS:**
```bash
chmod +x run-demo.sh
./run-demo.sh
```

### Demo Options

```bash
# Basic demo (default)
./run-demo.sh basic

# Performance test with large directory structure
./run-demo.sh performance

# Interactive session to try commands manually
./run-demo.sh interactive

# Build Docker image only
./run-demo.sh build

# Clean up Docker resources
./run-demo.sh clean
```

The demo creates realistic directory structures similar to `node_modules` and demonstrates FastDel's performance advantages.

## Installation

### Prerequisites
- Rust 1.70 or later
- Windows, macOS, or Linux

### Build from Source
```bash
git clone https://github.com/FunToHard/fastdel.git
cd fastdel
cargo build --release
```

The compiled binary will be available at `target/release/fastdel.exe` (Windows) or `target/release/fastdel` (Unix).

## Usage

### Basic Usage
```bash
# Delete a directory with confirmation
fastdel ./node_modules

# Skip confirmation prompt
fastdel -y ./node_modules

# Verbose output with progress tracking
fastdel -v ./large_directory

# Combine flags
fastdel -yv ./path/to/delete
```

### Command Line Options

```
fastdel [OPTIONS] <PATH>

Arguments:
  <PATH>  Directory path to delete (e.g., ./node_modules)

Options:
  -y, --yes      Skip confirmation prompt and delete immediately
  -v, --verbose  Enable verbose output with detailed progress
  -h, --help     Print help
  -V, --version  Print version
```

### Using FastDel with Docker

You can also use FastDel via Docker to delete real directories:

```bash
# Build the FastDel image
docker build -t fastdel .

# Delete a directory on your host system
docker run --rm -v "/path/to/delete:/target" fastdel fastdel -yv /target

# Interactive mode for exploring
docker run --rm -it -v "/path/to/workspace:/workspace" fastdel bash
```

**Windows example:**
```cmd
docker run --rm -v "C:\path\to\delete:/target" fastdel fastdel -yv /target
```

### Examples

```bash
# Delete node_modules with confirmation
fastdel ./node_modules

# Batch delete multiple directories
fastdel -y ./project1/node_modules
fastdel -y ./project2/node_modules  
fastdel -y ./project3/node_modules

# Delete with verbose progress tracking
fastdel -v ./large_build_output

# Force delete without confirmation (use with caution!)
fastdel -y ./temp_directory
```

## Output

FastDel provides clear, colorized output:

### Confirmation Prompt
```
⚠️  WARNING
You are about to permanently delete:
  C:\dev\nextjstest\node_modules

Are you sure you want to continue? (y/N):
```

### Progress Output (Verbose Mode)
```
🚀 Starting fast deletion...
Target: C:\dev\myproject\node_modules

Deleted file: C:\dev\myproject\node_modules\package\file.js
Deleted directory: C:\dev\myproject\node_modules\package
...
```

### Completion Summary
```
✅ Deletion completed successfully!

📊 Summary:
  Files deleted: 45,239
  Directories deleted: 8,412
  Space freed: 892.47 MB
  Time taken: 2.35s
  Performance: 19,251 files/sec
```

## Performance

FastDel is optimized for performance:

- **Concurrent Operations**: Files within each directory are processed concurrently
- **Async I/O**: Non-blocking file system operations
- **Minimal Overhead**: Direct system calls without unnecessary abstractions
- **Smart Traversal**: Depth-first traversal optimized for deletion order

### Benchmark Results

Typical performance on a directory with ~50,000 files:
- **Traditional `rm -rf`**: 15-30 seconds
- **FastDel**: 2-5 seconds
- **Improvement**: 3-6x faster

*Performance varies based on file system, disk type, and directory structure.*

## Safety Features

- **Confirmation Prompt**: Requires explicit confirmation before deletion
- **Path Validation**: Ensures target exists and is a directory
- **Error Handling**: Graceful handling of permission errors and locked files
- **Non-destructive by Default**: Will not delete without confirmation

## Technical Details

### Architecture

- **Language**: Rust (for memory safety and performance)
- **Async Runtime**: Tokio for concurrent operations
- **Error Handling**: Comprehensive error reporting with context
- **Cross-Platform**: Works on Windows, macOS, and Linux

### Long Path Support

FastDel handles Windows long path names (>260 characters) by:
- Using absolute path resolution
- Proper Unicode handling
- Working with Windows extended path prefixes

### Concurrency Model

- Processes files within each directory concurrently
- Uses depth-first recursive traversal for directories
- Limits concurrent operations to prevent resource exhaustion
- Thread-safe statistics tracking

## Troubleshooting

### Common Issues

**Permission Denied Errors**
```bash
# Run with elevated privileges (Windows)
# Right-click Command Prompt -> "Run as Administrator"
fastdel ./locked_directory
```

**Path Too Long (Windows)**
- FastDel automatically handles long paths
- Ensure you're using the absolute path

**Directory Not Empty Errors**
- FastDel handles this automatically by deleting contents first
- Check for hidden files or running processes

### Debug Mode

For debugging issues, use verbose mode:
```bash
fastdel -v ./problematic_directory
```

This will show detailed progress and any errors encountered.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Development Setup

```bash
git clone https://github.com/FunToHard/fastdel.git
cd fastdel
cargo build
cargo test
cargo run -- --help
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### v1.0.0
- Initial release
- Basic directory deletion functionality
- Concurrent file processing
- Progress tracking and statistics
- Cross-platform support
- Long path handling

## Acknowledgments

- Built with [Rust](https://www.rust-lang.org/) for performance and safety
- Uses [Tokio](https://tokio.rs/) for async runtime
- CLI powered by [clap](https://crates.io/crates/clap)
- Progress bars by [indicatif](https://crates.io/crates/indicatif)
- Colorized output by [colored](https://crates.io/crates/colored)

---

**⚠️ Warning**: This tool permanently deletes files and directories. Use with caution and always verify the target path before confirming deletion.
