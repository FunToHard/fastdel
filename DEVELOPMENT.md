# Development Guide for FastDel

This document outlines the architecture, design decisions, and development practices for FastDel.

## Architecture Overview

FastDel is designed with the following key principles:

### 1. **Performance First**
- Asynchronous I/O operations using Tokio
- Concurrent file deletion within directories
- Minimal memory allocation and copying
- Direct system calls through Rust's standard library

### 2. **Safety and Reliability**
- Memory safety guaranteed by Rust's ownership system
- Comprehensive error handling with `anyhow`
- Graceful degradation on permission errors
- Confirmation prompts to prevent accidental deletion

### 3. **Maintainability**
- Self-documenting code with extensive comments
- Clear separation of concerns
- Modular design with focused functions
- Comprehensive error messages

## Code Structure

### Main Components

#### `DeletionEngine`
The core engine that handles directory traversal and deletion:

```rust
struct DeletionEngine {
    stats: Arc<DeletionStats>,        // Thread-safe statistics
    progress_bar: Option<ProgressBar>, // Optional progress feedback
    verbose: bool,                    // Verbosity flag
}
```

**Key Methods:**
- `delete_directory()`: Main entry point, validates and orchestrates deletion
- `delete_directory_contents_concurrent()`: Recursive deletion with concurrency
- `remove_file()` / `remove_directory()`: Low-level deletion operations

#### `DeletionStats`
Thread-safe statistics tracking using atomic operations:

```rust
struct DeletionStats {
    files_deleted: AtomicU64,
    dirs_deleted: AtomicU64,
    errors_encountered: AtomicU64,
    bytes_freed: AtomicU64,
}
```

Uses `std::sync::atomic` for lock-free concurrent access.

#### CLI Interface
Built with `clap` for robust command-line parsing:
- Automatic help generation
- Type-safe argument parsing
- Integration with Rust's type system

## Design Decisions

### Async/Await Concurrency Model

**Why Async?**
- I/O operations are inherently blocking
- File system operations benefit from concurrency
- Tokio provides efficient task scheduling
- Better resource utilization than thread-per-file

**Recursion Handling:**
```rust
// Uses Box::pin to handle recursive async functions
Box::pin(self.delete_directory_contents_concurrent(&dir_path)).await?;
```

This prevents infinite-sized futures while maintaining async recursion.

### Error Handling Strategy

**Graceful Degradation:**
- Individual file failures don't stop the process
- Errors are logged and counted
- Process continues with remaining files
- Final summary includes error count

**Error Context:**
```rust
.with_context(|| format!("Failed to access path: {}", path.display()))?
```

Uses `anyhow` for rich error context without manual error type definitions.

### Memory Management

**Efficient Path Handling:**
- Uses `PathBuf` for owned paths when needed
- Borrows `&Path` when possible to avoid allocations
- Converts to absolute paths once to handle long Windows paths

**Streaming Directory Reading:**
```rust
while let Ok(Some(entry)) = entries.next_entry().await
```

Processes directory entries one at a time instead of loading all into memory.

### Cross-Platform Considerations

**Windows Long Paths:**
- Uses `canonicalize()` to get absolute paths
- Rust's standard library handles `\\?\` prefix automatically
- Works with paths longer than 260 characters

**Path Separators:**
- Uses `std::path` abstractions for platform independence
- Avoids hardcoded path separators

## Performance Optimizations

### Concurrent File Operations

Files within each directory are processed sequentially (not concurrently) to:
1. Avoid overwhelming the file system
2. Maintain predictable resource usage
3. Prevent permission conflicts
4. Ensure stable performance across different systems

### Directory Traversal Strategy

**Depth-First Recursive:**
- Deletes files first, then subdirectories
- Ensures directories are empty before deletion
- Minimizes memory usage for deep hierarchies
- Natural deletion order (leaves first)

### I/O Optimization

**Batch Operations:**
- Groups files by directory for efficient processing
- Minimizes directory handle open/close operations
- Reduces system call overhead

## Testing Strategy

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_file_deletion() {
        // Test individual file deletion
    }
    
    #[tokio::test]
    async fn test_empty_directory() {
        // Test empty directory handling
    }
}
```

### Integration Tests
```rust
// tests/integration_test.rs
#[tokio::test]
async fn test_complete_deletion_workflow() {
    // Create test directory structure
    // Run deletion
    // Verify results
}
```

### Manual Testing
- Create complex directory structures
- Test with various file permissions
- Verify long path handling on Windows
- Performance testing with large directories

## Dependencies

### Core Dependencies

- **`tokio`**: Async runtime and I/O operations
- **`anyhow`**: Error handling and context
- **`clap`**: Command-line interface

### UI Dependencies

- **`colored`**: Terminal color output
- **`indicatif`**: Progress bars and spinners
- **`futures`**: Additional async utilities

### Dependency Justification

Each dependency serves a specific purpose:
- **Tokio**: Essential for async I/O performance
- **Anyhow**: Significantly improves error handling ergonomics
- **Clap**: Industry standard for CLI applications in Rust
- **Colored/Indicatif**: Enhances user experience without performance impact

## Development Workflow

### Building
```bash
# Development build
cargo build

# Optimized release build
cargo build --release

# Run tests
cargo test

# Run clippy (linter)
cargo clippy

# Format code
cargo fmt
```

### Code Quality Tools

**Clippy Configuration:**
```toml
# Cargo.toml
[lints.clippy]
pedantic = "warn"
nursery = "warn"
```

**Format Configuration:**
```toml
# rustfmt.toml
edition = "2021"
tab_spaces = 4
max_width = 100
```

## Performance Profiling

### Profiling Tools
```bash
# CPU profiling with perf (Linux)
cargo build --release
perf record --call-graph=dwarf ./target/release/fastdel test_dir
perf report

# Memory profiling with valgrind
valgrind --tool=massif ./target/release/fastdel test_dir
```

### Benchmarking
```rust
// benches/deletion_benchmark.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_deletion(c: &mut Criterion) {
    c.bench_function("delete_large_directory", |b| {
        b.iter(|| {
            // Benchmark deletion operation
        })
    });
}
```

## Future Enhancements

### Planned Features
1. **Pattern Matching**: Delete files matching specific patterns
2. **Dry Run Mode**: Preview what would be deleted
3. **Parallel Directory Traversal**: Process multiple directories concurrently
4. **Recovery Mode**: Restore recently deleted files
5. **Configuration File**: User preferences and defaults

### Performance Improvements
1. **Memory Mapping**: For very large directories
2. **Custom Allocator**: Reduce allocation overhead
3. **Batch Syscalls**: Group operations where possible
4. **NUMA Awareness**: Optimize for multi-socket systems

## Contributing Guidelines

### Code Style
- Follow Rust standard formatting (`cargo fmt`)
- Use descriptive variable and function names
- Add documentation comments for public functions
- Include examples in documentation where helpful

### Pull Request Process
1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Ensure all tests pass
5. Update documentation if needed
6. Submit pull request with clear description

### Commit Message Format
```
type: brief description

Longer explanation if needed
- List changes
- Reference issues

Fixes #123
```

## Security Considerations

### Input Validation
- Validate all file paths
- Prevent directory traversal attacks
- Handle symbolic links safely
- Validate command-line arguments

### Permission Handling
- Respect file system permissions
- Fail gracefully on permission errors
- Don't attempt to escalate privileges
- Log permission-related errors

### Error Information
- Don't expose sensitive path information in errors
- Sanitize error messages for logs
- Avoid information disclosure through error messages

## License and Legal

This project is licensed under the MIT License. Contributors must:
- Have the right to contribute their code
- Agree to license contributions under MIT
- Not include copyrighted code without permission
- Follow responsible disclosure for security issues

---

This development guide should be updated as the project evolves and new patterns emerge.
