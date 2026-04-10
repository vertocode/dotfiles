use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process;

fn find_dir(root: &Path, target: &str) -> Option<PathBuf> {
    let entries = match fs::read_dir(root) {
        Ok(e) => e,
        Err(_) => return None,
    };

    let mut subdirs = Vec::new();

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let name = match entry.file_name().into_string() {
            Ok(n) => n,
            Err(_) => continue,
        };

        // Skip hidden directories and common non-project dirs
        if name.starts_with('.') {
            continue;
        }

        if name == target {
            return Some(path);
        }

        subdirs.push(path);
    }

    // BFS: search children after checking all entries at this level
    for sub in subdirs {
        if let Some(found) = find_dir(&sub, target) {
            return Some(found);
        }
    }

    None
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        eprintln!("usage: repo-open <folder_name>");
        process::exit(1);
    }

    let target = &args[1];
    let home = env::var("HOME").unwrap_or_else(|_| {
        eprintln!("error: HOME not set");
        process::exit(1);
    });

    let search_root = PathBuf::from(&home).join("Documents");

    if !search_root.is_dir() {
        eprintln!("error: {} does not exist", search_root.display());
        process::exit(1);
    }

    match find_dir(&search_root, target) {
        Some(path) => {
            // Print the path so the shell wrapper can cd to it
            println!("{}", path.display());
        }
        None => {
            eprintln!("error: folder '{}' not found under {}", target, search_root.display());
            process::exit(1);
        }
    }
}
