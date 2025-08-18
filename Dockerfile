# Use the official Rust image as base
FROM rust:1.80 AS builder

# Set the working directory
WORKDIR /app

# Copy the Cargo.toml and Cargo.lock files
COPY Cargo.toml Cargo.lock ./

# Copy the source code
COPY src ./src

# Build the application in release mode
RUN cargo build --release

# Create a new stage for the runtime
FROM debian:bookworm-slim

# Install necessary runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -u 1000 fastdel

# Copy the binary from the builder stage
COPY --from=builder /app/target/release/fastdel /usr/local/bin/fastdel

# Set the binary as executable
RUN chmod +x /usr/local/bin/fastdel

# Create a demo directory structure
RUN mkdir -p /demo/packages/package1/lib \
    && mkdir -p /demo/packages/package1/node_modules/dep1 \
    && mkdir -p /demo/packages/package1/node_modules/dep2/src \
    && mkdir -p /demo/packages/package2/dist \
    && mkdir -p /demo/packages/package2/node_modules/dep3

# Create demo files to simulate a real node_modules structure
RUN echo '{"name": "package1", "version": "1.0.0"}' > /demo/packages/package1/package.json \
    && echo 'console.log("Hello from package1");' > /demo/packages/package1/lib/index.js \
    && echo '{"name": "dep1", "version": "2.1.0"}' > /demo/packages/package1/node_modules/dep1/package.json \
    && echo 'module.exports = { dep1: true };' > /demo/packages/package1/node_modules/dep1/index.js \
    && echo '{"name": "dep2", "version": "1.5.2"}' > /demo/packages/package1/node_modules/dep2/package.json \
    && echo 'function dep2Function() { return "dep2"; }' > /demo/packages/package1/node_modules/dep2/src/main.js

RUN echo '{"name": "package2", "version": "3.0.1"}' > /demo/packages/package2/package.json \
    && echo '(function(){ console.log("Bundle loaded"); })();' > /demo/packages/package2/dist/bundle.js \
    && echo '{"name": "dep3", "version": "0.8.9"}' > /demo/packages/package2/node_modules/dep3/package.json \
    && echo 'exports.dep3 = { loaded: true };' > /demo/packages/package2/node_modules/dep3/index.js

# Create many small files to simulate a realistic node_modules scenario
RUN for i in $(seq 1 100); do \
        echo "// Auto-generated file $i" > "/demo/packages/package1/node_modules/dep1/file$i.js"; \
        echo "/* Dependency file $i */" > "/demo/packages/package1/node_modules/dep2/src/file$i.js"; \
        echo "// Utility $i" > "/demo/packages/package2/node_modules/dep3/util$i.js"; \
    done

# Create additional nested directories with files
RUN mkdir -p /demo/packages/package1/node_modules/dep1/deep/nested/structure \
    && mkdir -p /demo/packages/package2/node_modules/dep3/very/deep/nested/path/here \
    && for i in $(seq 1 50); do \
        echo "// Deep file $i" > "/demo/packages/package1/node_modules/dep1/deep/nested/structure/deep$i.js"; \
        echo "// Very deep file $i" > "/demo/packages/package2/node_modules/dep3/very/deep/nested/path/here/verydeep$i.js"; \
    done

# Set ownership of demo directory
RUN chown -R fastdel:fastdel /demo

# Switch to non-root user
USER fastdel

# Set the working directory
WORKDIR /home/fastdel

# Default command shows the demo
CMD ["/bin/bash", "-c", "echo '================================================' && \
     echo 'FastDel Demo - Fast Directory Deletion Tool' && \
     echo '================================================' && \
     echo && \
     echo 'Demo directory structure created with:' && \
     echo '  - Multiple packages with dependencies' && \
     echo '  - Deeply nested directory structures' && \
     echo '  - 200+ files across various directories' && \
     echo '  - Realistic node_modules-like layout' && \
     echo && \
     echo 'Directory structure overview:' && \
     find /demo -type d | head -15 && \
     echo '... and more directories' && \
     echo && \
     echo 'File count by directory:' && \
     find /demo -type f | wc -l && \
     echo 'files total' && \
     echo && \
     echo '================================================' && \
     echo 'Running FastDel with verbose output...' && \
     echo '================================================' && \
     echo && \
     fastdel -yv /demo && \
     echo && \
     echo '================================================' && \
     echo 'Demo completed!' && \
     echo '================================================' && \
     echo && \
     echo 'The demo directory has been successfully deleted.' && \
     echo 'FastDel efficiently removed all files and directories.' && \
     echo && \
     echo 'Key features demonstrated:' && \
     echo '  ✓ Recursive directory deletion' && \
     echo '  ✓ Concurrent file processing' && \
     echo '  ✓ Progress tracking and statistics' && \
     echo '  ✓ Cross-platform path handling' && \
     echo '  ✓ Graceful error handling' && \
     echo && \
     echo 'To use FastDel in your own environment:' && \
     echo '  docker run --rm -v /path/to/delete:/target fastdel-demo fastdel -yv /target' && \
     echo '  or build locally and run: fastdel [OPTIONS] <PATH>'"]
