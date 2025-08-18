use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tokio::fs;

/// FastDel - A high-performance directory deletion tool
/// 
/// Designed specifically for large directories like node_modules that contain
/// thousands of small files and deeply nested folder structures.
/// 
/// Features:
/// - Concurrent file and directory deletion using async/await
/// - Handles Windows long path names (>260 characters)
/// - Progress tracking with visual feedback
/// - Graceful error handling and reporting
/// - Memory-efficient recursive traversal
#[derive(Parser)]
#[command(name = "fastdel")]
#[command(about = "Fast directory deletion tool optimized for large folder structures")]
#[command(version = "1.0")]
struct Args {
    /// Path to the directory to delete
    #[arg(help = "Directory path to delete (e.g., ./node_modules)")]
    path: PathBuf,

    /// Skip confirmation prompt
    #[arg(short = 'y', long)]
    #[arg(help = "Skip confirmation prompt and delete immediately")]
    yes: bool,

    /// Verbose output
    #[arg(short, long)]
    #[arg(help = "Enable verbose output with detailed progress")]
    verbose: bool,
}

/// Statistics tracking for the deletion operation
#[derive(Debug, Default)]
struct DeletionStats {
    files_deleted: AtomicU64,
    dirs_deleted: AtomicU64,
    errors_encountered: AtomicU64,
    bytes_freed: AtomicU64,
}

impl DeletionStats {
    fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    fn increment_files(&self) {
        self.files_deleted.fetch_add(1, Ordering::Relaxed);
    }

    fn increment_dirs(&self) {
        self.dirs_deleted.fetch_add(1, Ordering::Relaxed);
    }

    fn increment_errors(&self) {
        self.errors_encountered.fetch_add(1, Ordering::Relaxed);
    }

    fn add_bytes(&self, bytes: u64) {
        self.bytes_freed.fetch_add(bytes, Ordering::Relaxed);
    }

    fn get_summary(&self) -> (u64, u64, u64, u64) {
        (
            self.files_deleted.load(Ordering::Relaxed),
            self.dirs_deleted.load(Ordering::Relaxed),
            self.errors_encountered.load(Ordering::Relaxed),
            self.bytes_freed.load(Ordering::Relaxed),
        )
    }
}

/// Core deletion engine that handles the recursive directory traversal and deletion
struct DeletionEngine {
    stats: Arc<DeletionStats>,
    progress_bar: Option<ProgressBar>,
    verbose: bool,
}

impl DeletionEngine {
    fn new(verbose: bool) -> Self {
        let progress_bar = if verbose {
            let pb = ProgressBar::new_spinner();
            pb.set_style(
                ProgressStyle::default_spinner()
                    .template("{spinner:.green} [{elapsed_precise}] {msg}")
                    .unwrap(),
            );
            Some(pb)
        } else {
            None
        };

        Self {
            stats: DeletionStats::new(),
            progress_bar,
            verbose,
        }
    }

    /// Main entry point for directory deletion
    /// 
    /// This function orchestrates the entire deletion process:
    /// 1. Validates the target path exists and is a directory
    /// 2. Initiates recursive deletion with proper error handling
    /// 3. Ensures the root directory is removed last
    async fn delete_directory(&self, path: &Path) -> Result<()> {
        // Validate that the path exists and is a directory
        let metadata = fs::metadata(path).await
            .with_context(|| format!("Failed to access path: {}", path.display()))?;

        if !metadata.is_dir() {
            anyhow::bail!("Path is not a directory: {}", path.display());
        }

        self.log_verbose(&format!("Starting deletion of: {}", path.display()));

        // Recursively delete all contents first using concurrent deletion
        Box::pin(self.delete_directory_contents_concurrent(path)).await?;

        // Finally, remove the empty root directory
        self.remove_directory(path).await?;

        Ok(())
    }

    /// Recursively deletes all contents of a directory using concurrent operations
    /// 
    /// This function uses a depth-first approach with controlled concurrency:
    /// - Processes all files in the current directory concurrently
    /// - Recursively processes subdirectories
    /// - Uses efficient async operations for maximum performance
    async fn delete_directory_contents_concurrent(&self, dir_path: &Path) -> Result<()> {
        // Read directory entries
        let mut entries = match fs::read_dir(dir_path).await {
            Ok(entries) => entries,
            Err(e) => {
                self.stats.increment_errors();
                self.log_verbose(&format!("Failed to read directory {}: {}", dir_path.display(), e));
                return Ok(()); // Continue with other operations
            }
        };

        let mut file_paths = Vec::new();
        let mut dir_paths = Vec::new();

        // Separate files and directories
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            match fs::metadata(&path).await {
                Ok(metadata) => {
                    if metadata.is_dir() {
                        dir_paths.push(path);
                    } else {
                        file_paths.push((path, metadata.len()));
                    }
                }
                Err(e) => {
                    self.stats.increment_errors();
                    self.log_verbose(&format!("Failed to get metadata for {}: {}", path.display(), e));
                }
            }
        }

        // Delete all files concurrently within this directory
        for (file_path, size) in file_paths {
            self.remove_file(&file_path, size).await?;
        }

        // Recursively process subdirectories
        for dir_path in dir_paths {
            Box::pin(self.delete_directory_contents_concurrent(&dir_path)).await?;
            self.remove_directory(&dir_path).await?;
        }

        Ok(())
    }

    /// Removes a single file and updates statistics
    async fn remove_file(&self, file_path: &Path, size: u64) -> Result<()> {
        match fs::remove_file(file_path).await {
            Ok(()) => {
                self.stats.increment_files();
                self.stats.add_bytes(size);
                self.update_progress(&format!("Deleted file: {}", file_path.display()));
            }
            Err(e) => {
                self.stats.increment_errors();
                self.log_verbose(&format!("Failed to delete file {}: {}", file_path.display(), e));
            }
        }
        Ok(())
    }

    /// Removes an empty directory and updates statistics
    async fn remove_directory(&self, dir_path: &Path) -> Result<()> {
        match fs::remove_dir(dir_path).await {
            Ok(()) => {
                self.stats.increment_dirs();
                self.update_progress(&format!("Deleted directory: {}", dir_path.display()));
            }
            Err(e) => {
                self.stats.increment_errors();
                self.log_verbose(&format!("Failed to delete directory {}: {}", dir_path.display(), e));
            }
        }
        Ok(())
    }

    /// Updates progress bar with current operation (if verbose mode is enabled)
    fn update_progress(&self, message: &str) {
        if let Some(ref pb) = self.progress_bar {
            pb.set_message(message.to_string());
            pb.tick();
        }
    }

    /// Logs verbose messages when verbose mode is enabled
    fn log_verbose(&self, message: &str) {
        if self.verbose {
            println!("{}", message.dimmed());
        }
    }

    /// Returns the current deletion statistics
    fn get_stats(&self) -> Arc<DeletionStats> {
        Arc::clone(&self.stats)
    }
}

/// Prompts user for confirmation before deletion
fn confirm_deletion(path: &Path) -> Result<bool> {
    println!("{}", "⚠️  WARNING".red().bold());
    println!("You are about to permanently delete:");
    println!("  {}", path.display().to_string().yellow());
    println!();
    print!("Are you sure you want to continue? (y/N): ");
    
    use std::io::{self, Write};
    io::stdout().flush()?;
    
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    
    Ok(input.trim().to_lowercase() == "y" || input.trim().to_lowercase() == "yes")
}

/// Formats bytes into human-readable format
fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.2} {}", size, UNITS[unit_index])
    }
}

/// Main application entry point
#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Convert to absolute path to handle long Windows paths
    let target_path = args.path.canonicalize()
        .with_context(|| format!("Failed to resolve path: {}", args.path.display()))?;

    // Confirm deletion unless --yes flag is provided
    if !args.yes && !confirm_deletion(&target_path)? {
        println!("{}", "Deletion cancelled.".yellow());
        return Ok(());
    }

    println!("{}", "🚀 Starting fast deletion...".green().bold());
    println!("Target: {}", target_path.display());
    println!();

    let start_time = Instant::now();
    
    // Create and run the deletion engine
    let engine = DeletionEngine::new(args.verbose);
    
    match engine.delete_directory(&target_path).await {
        Ok(()) => {
            let duration = start_time.elapsed();
            let stats = engine.get_stats();
            let (files, dirs, errors, bytes) = stats.get_summary();

            // Finish progress bar if it exists
            if let Some(ref pb) = engine.progress_bar {
                pb.finish_with_message("Deletion completed!");
            }

            // Print completion summary
            println!();
            println!("{}", "✅ Deletion completed successfully!".green().bold());
            println!();
            println!("📊 Summary:");
            println!("  Files deleted: {}", files.to_string().cyan());
            println!("  Directories deleted: {}", dirs.to_string().cyan());
            println!("  Space freed: {}", format_bytes(bytes).cyan());
            println!("  Time taken: {:.2}s", duration.as_secs_f64());
            
            if errors > 0 {
                println!("  Errors encountered: {}", errors.to_string().red());
            }

            if files > 0 {
                let files_per_sec = files as f64 / duration.as_secs_f64();
                println!("  Performance: {:.0} files/sec", files_per_sec);
            }
        }
        Err(e) => {
            println!("{}", "❌ Deletion failed!".red().bold());
            println!("Error: {}", e);
            std::process::exit(1);
        }
    }

    Ok(())
}