use std::collections::BTreeMap;
use std::process::{self, Command};

struct PortEntry {
    proto: String,
    port: u16,
    pid: String,
    process_name: String,
}

fn main() {
    let output = Command::new("lsof")
        .args(["-iTCP", "-iUDP", "-sTCP:LISTEN", "-nP"])
        .output()
        .unwrap_or_else(|e| {
            eprintln!("error: failed to run lsof: {e}");
            process::exit(1);
        });

    let stdout = String::from_utf8_lossy(&output.stdout);

    // Parse lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    let mut ports: BTreeMap<u16, Vec<PortEntry>> = BTreeMap::new();

    for line in stdout.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 10 {
            continue;
        }

        let process_name = cols[0].to_string();
        let pid = cols[1].to_string();
        let proto = cols[8].to_string();
        let name = cols[9];

        let port_str = match name.rsplit_once(':') {
            Some((_, p)) => p,
            None => continue,
        };

        let port: u16 = match port_str.parse() {
            Ok(p) => p,
            Err(_) => continue,
        };

        ports.entry(port).or_default().push(PortEntry {
            proto,
            port,
            pid,
            process_name,
        });
    }

    if ports.is_empty() {
        println!("No listening ports found.");
        return;
    }

    println!("{:<8} {:<7} {:<8} {}", "PORT", "PROTO", "PID", "PROCESS");
    println!("{}", "-".repeat(50));

    for (_port, entries) in &ports {
        for entry in entries {
            println!(
                "{:<8} {:<7} {:<8} {}",
                entry.port, entry.proto, entry.pid, entry.process_name
            );
        }
    }

    println!("\nTotal: {} port(s) in use.", ports.len());
}
