use std::env;
use std::fs;
use std::process;

const TARGETS: &[&str] = &[
    "node_modules",
    ".next",
    "dist",
    ".dist",
    "build",
    ".cache",
    ".turbo",
    ".parcel-cache",
    ".nuxt",
    ".output",
    ".svelte-kit",
    "coverage",
    ".nyc_output",
    "out",
    ".vercel",
    ".netlify",
];

fn main() {
    let dir = env::current_dir().unwrap_or_else(|e| {
        eprintln!("error: could not read current directory: {e}");
        process::exit(1);
    });

    println!("Scanning {} ...", dir.display());

    let mut removed = 0u32;

    for name in TARGETS {
        let path = dir.join(name);
        if path.exists() {
            let is_dir = path.is_dir();
            let result = if is_dir {
                fs::remove_dir_all(&path)
            } else {
                fs::remove_file(&path)
            };

            match result {
                Ok(()) => {
                    let kind = if is_dir { "directory" } else { "file" };
                    println!("  removed {kind}: {name}");
                    removed += 1;
                }
                Err(e) => {
                    eprintln!("  failed to remove {name}: {e}");
                }
            }
        }
    }

    if removed == 0 {
        println!("Nothing to clean.");
    } else {
        println!("Done. Removed {removed} item(s).");
    }
}
