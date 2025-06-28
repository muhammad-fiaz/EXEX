use crate::models::{Config, ServerConfig, SecurityConfig, LoggingConfig};
use std::fs;
use std::path::PathBuf;
use tracing::{info, warn, error};

/// Gets the config directory path based on the operating system
fn get_config_dir() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let config_dir = if cfg!(target_os = "windows") {
        let mut dir = dirs::data_local_dir()
            .ok_or("Could not determine local data directory")?;
        dir.push("EXEX");
        dir
    } else if cfg!(target_os = "macos") {
        let mut dir = dirs::home_dir()
            .ok_or("Could not determine home directory")?;
        dir.push("Library/Application Support/EXEX");
        dir
    } else {
        // Linux and other Unix-like systems
        let mut dir = dirs::config_dir()
            .ok_or("Could not determine config directory")?;
        dir.push("exex");
        dir
    };
    
    Ok(config_dir)
}

/// Gets the full config file path
fn get_config_file_path() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let mut config_path = get_config_dir()?;
    config_path.push("exex.config.json");
    Ok(config_path)
}

/// Returns the default configuration with cross-platform paths
pub fn get_default_config() -> Config {
    let (disallowed_paths, allowed_paths) = if cfg!(target_os = "windows") {
        (
            vec![
                "C:/Windows/".to_string(),
                "C:/Program Files/".to_string(),
                "C:/Program Files (x86)/".to_string(),
                "C:/Windows/System32/".to_string(),
                "C:/Users/*/AppData/Roaming/".to_string(),
                "C:/ProgramData/".to_string(),
                "C:/System Volume Information/".to_string(),
                "C:/$Recycle.Bin/".to_string(),
            ],
            vec![
                "C:/Windows/Temp/".to_string(),
                "C:/Users/*/AppData/Local/EXEX/".to_string(),
                "C:/Users/*/Projects/".to_string(),
                "C:/temp/".to_string(),
                "C:/tmp/".to_string(),
            ]
        )
    } else if cfg!(target_os = "macos") {
        (
            vec![
                "/System/".to_string(),
                "/Library/".to_string(),
                "/Applications/".to_string(),
                "/usr/".to_string(),
                "/private/".to_string(),
                "/etc/".to_string(),
                "/boot/".to_string(),
                "/sys/".to_string(),
                "/proc/".to_string(),
                "/dev/".to_string(),
                "/root/".to_string(),
                "/bin/".to_string(),
                "/sbin/".to_string(),
                "/var/log/".to_string(),
            ],
            vec![
                "/tmp/".to_string(),
                "/var/tmp/".to_string(),
                "/Users/*/Projects/".to_string(),
                "/Users/*/Documents/".to_string(),
                "/Users/*/Downloads/".to_string(),
                "/Users/*/Desktop/".to_string(),
            ]
        )
    } else {
        // Linux and other Unix-like systems
        (
            vec![
                "/etc/".to_string(),
                "/boot/".to_string(),
                "/sys/".to_string(),
                "/proc/".to_string(),
                "/dev/".to_string(),
                "/root/".to_string(),
                "/usr/bin/".to_string(),
                "/usr/sbin/".to_string(),
                "/sbin/".to_string(),
                "/bin/".to_string(),
                "/var/log/".to_string(),
                "/lib/".to_string(),
                "/lib64/".to_string(),
            ],
            vec![
                "/tmp/".to_string(),
                "/var/tmp/".to_string(),
                "/home/*/Projects/".to_string(),
                "/home/*/Documents/".to_string(),
                "/home/*/Downloads/".to_string(),
                "/home/*/Desktop/".to_string(),
            ]
        )
    };

    // Get default audit file path
    let audit_file = get_config_dir()
        .map(|mut path| {
            path.push("audit.log");
            path.to_string_lossy().to_string()
        })
        .unwrap_or_else(|_| "audit.log".to_string());

    Config {
        version: "1.0".to_string(),
        server: ServerConfig {
            host: "127.0.0.1".to_string(),
            port: 8080,
        },
        security: SecurityConfig {
            allowed_paths,
            disallowed_paths,
            command_whitelist: vec![
                "npm".to_string(),
                "node".to_string(),
                "git".to_string(),
                "code".to_string(),
                "python".to_string(),
                "pip".to_string(),
                "cargo".to_string(),
                "rustc".to_string(),
                "echo".to_string(),
                "dir".to_string(),
                "ls".to_string(),
                "pwd".to_string(),
                "whoami".to_string(),
            ],
            command_blacklist: Some(vec![
                "rm".to_string(),
                "rmdir".to_string(),
                "del".to_string(),
                "format".to_string(),
                "fdisk".to_string(),
                "shutdown".to_string(),
                "reboot".to_string(),
                "halt".to_string(),
                "poweroff".to_string(),
                "mkfs".to_string(),
                "dd".to_string(),
                "sudo".to_string(),
                "su".to_string(),
                "passwd".to_string(),
                "chmod".to_string(),
                "chown".to_string(),
            ]),
            max_file_size_mb: 100,
        },
        logging: LoggingConfig {
            level: "info".to_string(),
            audit_file,
        },
    }
}

/// Validates the configuration structure and content
pub fn validate_config(config: &Config) -> Result<(), String> {
    // Check required fields
    if config.version.trim().is_empty() {
        return Err("Configuration must have a version field".to_string());
    }
    
    if config.server.host.trim().is_empty() {
        return Err("Server host cannot be empty".to_string());
    }
    
    if config.server.port == 0 {
        return Err("Server port must be greater than 0".to_string());
    }
    
    // Validate security configuration
    if config.security.max_file_size_mb == 0 {
        return Err("Max file size must be greater than 0".to_string());
    }
    
    // Validate path content
    for path in &config.security.disallowed_paths {
        if path.trim().is_empty() {
            return Err("Disallowed paths cannot be empty".to_string());
        }
    }
    
    for path in &config.security.allowed_paths {
        if path.trim().is_empty() {
            return Err("Allowed paths cannot be empty".to_string());
        }
    }
    
    // Validate command lists
    for cmd in &config.security.command_whitelist {
        if cmd.trim().is_empty() {
            return Err("Command whitelist entries cannot be empty".to_string());
        }
    }
    
    if let Some(blacklist) = &config.security.command_blacklist {
        for cmd in blacklist {
            if cmd.trim().is_empty() {
                return Err("Command blacklist entries cannot be empty".to_string());
            }
        }
    }
    
    // Platform-specific critical path checks
    let critical_paths = if cfg!(target_os = "windows") {
        vec!["C:/Windows/", "C:/Program Files/"]
    } else if cfg!(target_os = "macos") {
        vec!["/System/", "/Library/"]
    } else {
        vec!["/etc/", "/usr/bin/", "/root/"]
    };
    
    for critical in &critical_paths {
        if !config.security.disallowed_paths.iter().any(|p| p.contains(critical)) {
            warn!("Critical path {} is not in disallowed paths", critical);
        }
    }
    
    info!("Configuration validation successful:");
    info!("  Version: {}", config.version);
    info!("  Server: {}:{}", config.server.host, config.server.port);
    info!("  Disallowed paths: {}", config.security.disallowed_paths.len());
    info!("  Allowed paths: {}", config.security.allowed_paths.len());
    info!("  Command whitelist: {}", config.security.command_whitelist.len());
    info!("  Max file size: {} MB", config.security.max_file_size_mb);
    
    Ok(())
}

/// Loads configuration from the appropriate config directory
/// Creates the config file with defaults if it doesn't exist
/// If config exists but is invalid, returns default config with warning (never terminates)
pub fn load_config() -> Config {
    // Get config file path
    let config_path = match get_config_file_path() {
        Ok(path) => path,
        Err(e) => {
            error!("Failed to determine config file path: {}", e);
            warn!("Using default configuration due to path error");
            return get_default_config();
        }
    };

    info!("Config file location: {}", config_path.display());

    // Create config directory if it doesn't exist
    if let Some(parent) = config_path.parent() {
        if !parent.exists() {
            info!("Creating config directory: {}", parent.display());
            if let Err(e) = fs::create_dir_all(parent) {
                error!("Failed to create config directory: {}", e);
                warn!("Using default configuration due to directory creation error");
                return get_default_config();
            }
        }
    }

    // Check if config file exists
    if config_path.exists() {
        info!("Found existing config file, loading...");
        
        // Read and parse existing config
        let content = match fs::read_to_string(&config_path) {
            Ok(content) => content,
            Err(e) => {
                error!("Failed to read existing config file: {}", e);
                warn!("Config file exists but cannot be read. Using default configuration.");
                return get_default_config();
            }
        };
        
        let config = match serde_json::from_str::<Config>(&content) {
            Ok(config) => config,
            Err(e) => {
                error!("Failed to parse existing config file: {}", e);
                warn!("Config file structure is invalid. Using default configuration.");
                warn!("You can delete the config file at {} to recreate it with defaults.", config_path.display());
                return get_default_config();
            }
        };
        
        // Validate the loaded config
        if let Err(e) = validate_config(&config) {
            error!("Existing configuration validation failed: {}", e);
            warn!("Config file is invalid. Using default configuration.");
            warn!("You can delete the config file at {} to recreate it with defaults.", config_path.display());
            return get_default_config();
        }
        
        info!("Successfully loaded and validated existing configuration");
        return config;
    } else {
        info!("Config file doesn't exist, creating with defaults");
        
        // Create new config file with defaults
        let default_config = get_default_config();
        
        // Validate default config (should never fail, but safety check)
        if let Err(e) = validate_config(&default_config) {
            error!("Default configuration is invalid: {}", e);
            warn!("Critical error in default config, but continuing with it anyway");
        }
        
        // Write the config file
        match serde_json::to_string_pretty(&default_config) {
            Ok(json_content) => {
                if let Err(e) = fs::write(&config_path, json_content) {
                    error!("Failed to write new config file: {}", e);
                    warn!("Cannot create config file, but continuing with default configuration in memory");
                } else {
                    info!("Created new config file: {}", config_path.display());
                }
            }
            Err(e) => {
                error!("Failed to serialize default config: {}", e);
                warn!("Cannot serialize config, but continuing with default configuration in memory");
            }
        }
        
        info!("Using default configuration");
        return default_config;
    }
}
