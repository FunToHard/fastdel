#!/usr/bin/env bash

# FastDel Docker Demo Runner
# Cross-platform demo script using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        echo "Please install Docker to run the demo:"
        echo "  - Windows/macOS: https://www.docker.com/products/docker-desktop"
        echo "  - Linux: https://docs.docker.com/engine/install/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        echo "Please start Docker and try again."
        exit 1
    fi

    print_success "Docker is available and running"
}

# Check if Docker Compose is available
check_docker_compose() {
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        print_error "Docker Compose is not available"
        echo "Please install Docker Compose or use a newer version of Docker that includes it."
        exit 1
    fi

    print_success "Docker Compose is available"
}

# Build the FastDel Docker image
build_image() {
    print_header "Building FastDel Docker Image"
    
    print_info "This may take a few minutes on first run..."
    
    if docker build -t fastdel:demo . --quiet; then
        print_success "FastDel Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
    
    echo
}

# Run basic demo
run_basic_demo() {
    print_header "FastDel Basic Demo"
    
    print_info "Running basic deletion demo with sample directory structure..."
    echo
    
    $DOCKER_COMPOSE --profile demo up --remove-orphans fastdel-demo
    
    echo
    print_success "Basic demo completed"
}

# Run performance demo
run_performance_demo() {
    print_header "FastDel Performance Demo"
    
    print_info "Creating large directory structure and measuring performance..."
    print_warning "This demo creates ~10,000 files and may take longer to run"
    echo
    
    $DOCKER_COMPOSE --profile performance up --remove-orphans fastdel-performance
    
    echo
    print_success "Performance demo completed"
}

# Run interactive demo
run_interactive_demo() {
    print_header "FastDel Interactive Demo"
    
    print_info "Starting interactive session..."
    print_info "You'll be able to run FastDel commands manually"
    print_info "Type 'exit' to leave the interactive session"
    echo
    
    $DOCKER_COMPOSE --profile interactive up --remove-orphans fastdel-interactive
    
    echo
    print_success "Interactive demo session ended"
}

# Show usage information
show_usage() {
    echo "FastDel Docker Demo Runner"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  basic        Run basic demo with sample directory structure"
    echo "  performance  Run performance demo with large directory structure"
    echo "  interactive  Start interactive demo session"
    echo "  build        Build the Docker image only"
    echo "  clean        Clean up Docker resources"
    echo "  help         Show this help message"
    echo
    echo "If no command is specified, runs the basic demo."
    echo
    echo "Requirements:"
    echo "  - Docker installed and running"
    echo "  - Docker Compose available"
    echo
    echo "Examples:"
    echo "  $0                 # Run basic demo"
    echo "  $0 basic           # Run basic demo"
    echo "  $0 performance     # Run performance test"
    echo "  $0 interactive     # Start interactive session"
    echo
}

# Clean up Docker resources
clean_up() {
    print_header "Cleaning Up Docker Resources"
    
    print_info "Stopping and removing containers..."
    $DOCKER_COMPOSE down --remove-orphans --volumes 2>/dev/null || true
    
    print_info "Removing FastDel demo images..."
    docker rmi fastdel:demo 2>/dev/null || true
    
    print_info "Removing unused volumes..."
    docker volume prune -f >/dev/null 2>&1 || true
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    # Handle command line arguments
    case "${1:-basic}" in
        "help"|"-h"|"--help")
            show_usage
            exit 0
            ;;
        "clean")
            check_docker
            clean_up
            exit 0
            ;;
        "build")
            check_docker
            build_image
            exit 0
            ;;
        "basic")
            check_docker
            check_docker_compose
            build_image
            run_basic_demo
            ;;
        "performance")
            check_docker
            check_docker_compose
            build_image
            run_performance_demo
            ;;
        "interactive")
            check_docker
            check_docker_compose
            build_image
            run_interactive_demo
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
