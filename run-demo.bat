@echo off
setlocal enabledelayedexpansion

REM FastDel Docker Demo Runner for Windows
REM Cross-platform demo script using Docker

REM Function to print headers
:print_header
echo.
echo ================================================
echo %~1
echo ================================================
echo.
goto :eof

REM Function to print success messages
:print_success
echo [92m✓ %~1[0m
goto :eof

REM Function to print warnings
:print_warning
echo [93m⚠ %~1[0m
goto :eof

REM Function to print errors
:print_error
echo [91m✗ %~1[0m
goto :eof

REM Function to print info messages
:print_info
echo [96mℹ %~1[0m
goto :eof

REM Check if Docker is available
:check_docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo [91m✗ Docker is not installed or not in PATH[0m
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo [91m✗ Docker is not running[0m
    echo Please start Docker Desktop and try again.
    exit /b 1
)

echo [92m✓ Docker is available and running[0m
goto :eof

REM Check if Docker Compose is available
:check_docker_compose
docker compose version >nul 2>&1
if not errorlevel 1 (
    set "DOCKER_COMPOSE=docker compose"
    echo [92m✓ Docker Compose is available[0m
    goto :eof
)

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    set "DOCKER_COMPOSE=docker-compose"
    echo [92m✓ Docker Compose is available[0m
    goto :eof
)

echo [91m✗ Docker Compose is not available[0m
echo Please install Docker Compose or use a newer version of Docker that includes it.
exit /b 1

REM Build the FastDel Docker image
:build_image
call :print_header "Building FastDel Docker Image"
echo [96mℹ This may take a few minutes on first run...[0m

docker build -t fastdel:demo . --quiet
if errorlevel 1 (
    echo [91m✗ Failed to build Docker image[0m
    exit /b 1
)

echo [92m✓ FastDel Docker image built successfully[0m
echo.
goto :eof

REM Run basic demo
:run_basic_demo
call :print_header "FastDel Basic Demo"
echo [96mℹ Running basic deletion demo with sample directory structure...[0m
echo.

%DOCKER_COMPOSE% --profile demo up --remove-orphans fastdel-demo

echo.
echo [92m✓ Basic demo completed[0m
goto :eof

REM Run performance demo
:run_performance_demo
call :print_header "FastDel Performance Demo"
call :print_info "Creating large directory structure and measuring performance..."
call :print_warning "This demo creates ~10,000 files and may take longer to run"
echo.

%DOCKER_COMPOSE% --profile performance up --remove-orphans fastdel-performance

echo.
call :print_success "Performance demo completed"
goto :eof

REM Run interactive demo
:run_interactive_demo
call :print_header "FastDel Interactive Demo"
call :print_info "Starting interactive session..."
call :print_info "You'll be able to run FastDel commands manually"
call :print_info "Type 'exit' to leave the interactive session"
echo.

%DOCKER_COMPOSE% --profile interactive up --remove-orphans fastdel-interactive

echo.
call :print_success "Interactive demo session ended"
goto :eof

REM Show usage information
:show_usage
echo FastDel Docker Demo Runner
echo.
echo Usage: %~nx0 [COMMAND]
echo.
echo Commands:
echo   basic        Run basic demo with sample directory structure
echo   performance  Run performance demo with large directory structure
echo   interactive  Start interactive demo session
echo   build        Build the Docker image only
echo   clean        Clean up Docker resources
echo   help         Show this help message
echo.
echo If no command is specified, runs the basic demo.
echo.
echo Requirements:
echo   - Docker Desktop installed and running
echo   - Docker Compose available
echo.
echo Examples:
echo   %~nx0                 # Run basic demo
echo   %~nx0 basic           # Run basic demo
echo   %~nx0 performance     # Run performance test
echo   %~nx0 interactive     # Start interactive session
echo.
goto :eof

REM Clean up Docker resources
:clean_up
call :print_header "Cleaning Up Docker Resources"

call :print_info "Stopping and removing containers..."
%DOCKER_COMPOSE% down --remove-orphans --volumes >nul 2>&1

call :print_info "Removing FastDel demo images..."
docker rmi fastdel:demo >nul 2>&1

call :print_info "Removing unused volumes..."
docker volume prune -f >nul 2>&1

call :print_success "Cleanup completed"
goto :eof

REM Main execution
set "command=%~1"
if "%command%"=="" set "command=basic"

if "%command%"=="help" goto :show_help
if "%command%"=="-h" goto :show_help
if "%command%"=="--help" goto :show_help
if "%command%"=="clean" goto :run_clean
if "%command%"=="build" goto :run_build
if "%command%"=="basic" goto :run_basic
if "%command%"=="performance" goto :run_performance
if "%command%"=="interactive" goto :run_interactive

call :print_error "Unknown command: %command%"
echo.
call :show_usage
exit /b 1

:show_help
call :show_usage
exit /b 0

:run_clean
call :check_docker
call :clean_up
exit /b 0

:run_build
call :check_docker
call :build_image
exit /b 0

:run_basic
call :check_docker
call :check_docker_compose
call :build_image
call :run_basic_demo
exit /b 0

:run_performance
call :check_docker
call :check_docker_compose
call :build_image
call :run_performance_demo
exit /b 0

:run_interactive
call :check_docker
call :check_docker_compose
call :build_image
call :run_interactive_demo
exit /b 0
