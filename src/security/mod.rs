use std::collections::HashSet;
use std::path::{Path, PathBuf};
use crate::models::Config;

/// Application state containing security policies
pub struct SecurityManager {
    disallowed_paths: HashSet<PathBuf>,
    allowed_paths: HashSet<PathBuf>,
    command_whitelist: HashSet<String>,
    command_blacklist: HashSet<String>,
    max_file_size_mb: u64,
}

impl SecurityManager {
    /// Creates a new SecurityManager from configuration
    pub fn new(config: Config) -> Self {
        use tracing::debug;
        
        let disallowed_paths = config
            .security
            .disallowed_paths
            .into_iter()
            .filter_map(|p| {
                // Normalize paths based on platform
                let normalized = if cfg!(target_os = "windows") {
                    p.replace('/', "\\")
                } else {
                    p.replace('\\', "/")
                };
                let path = PathBuf::from(normalized);
                
                // Try to canonicalize the disallowed path
                match path.canonicalize() {
                    Ok(canonical) => {
                        debug!("Added disallowed path: {:?} (canonical: {:?})", path, canonical);
                        Some(canonical)
                    },
                    Err(e) => {
                        debug!("Could not canonicalize disallowed path {:?}: {}, using as-is", path, e);
                        // If canonicalization fails, use the path as-is (it might not exist yet)
                        Some(path)
                    }
                }
            })
            .collect();
            
        let allowed_paths = config
            .security
            .allowed_paths
            .into_iter()
            .filter_map(|p| {
                // Normalize paths based on platform
                let normalized = if cfg!(target_os = "windows") {
                    p.replace('/', "\\")
                } else {
                    p.replace('\\', "/")
                };
                let path = PathBuf::from(normalized);
                
                // Try to canonicalize the allowed path
                match path.canonicalize() {
                    Ok(canonical) => {
                        debug!("Added allowed path exception: {:?} (canonical: {:?})", path, canonical);
                        Some(canonical)
                    },
                    Err(e) => {
                        debug!("Could not canonicalize allowed path {:?}: {}, using as-is", path, e);
                        // If canonicalization fails, use the path as-is (it might not exist yet)
                        Some(path)
                    }
                }
            })
            .collect();
            
        let command_whitelist = config
            .security
            .command_whitelist
            .into_iter()
            .collect();
            
        let command_blacklist = config
            .security
            .command_blacklist
            .unwrap_or_default()
            .into_iter()
            .collect();
        
        Self { 
            disallowed_paths, 
            allowed_paths,
            command_whitelist,
            command_blacklist,
            max_file_size_mb: config.security.max_file_size_mb,
        }
    }

    /// Checks if a command is allowed to be executed
    pub fn is_command_allowed(&self, command: &str) -> bool {
        use tracing::{debug, warn};
        
        debug!("Checking command access for: {}", command);
        
        // Extract the base command (first word)
        let base_command = command.split_whitespace().next().unwrap_or(command);
        
        // Remove path and extension to get base command name
        let command_name = if let Some(path) = Path::new(base_command).file_stem() {
            path.to_string_lossy().to_string()
        } else {
            base_command.to_string()
        };
        
        debug!("Base command extracted: {}", command_name);
        
        // First check blacklist - if it's blacklisted, deny immediately
        if self.command_blacklist.contains(&command_name) {
            warn!("Command '{}' is blacklisted", command_name);
            return false;
        }
        
        // If whitelist is not empty, command must be in whitelist
        if !self.command_whitelist.is_empty() {
            let allowed = self.command_whitelist.contains(&command_name);
            if !allowed {
                warn!("Command '{}' not in whitelist", command_name);
            }
            allowed
        } else {
            // If no whitelist specified, allow all commands not in blacklist
            debug!("No whitelist specified, allowing command '{}'", command_name);
            true
        }
    }

    /// Checks if a file size is within limits
    pub fn is_file_size_allowed(&self, size_bytes: u64) -> bool {
        let size_mb = size_bytes / (1024 * 1024);
        size_mb <= self.max_file_size_mb
    }

    /// Checks if a path is allowed based on security policies
    /// Priority: 
    /// 1. First check if path is explicitly allowed (allowed_paths override disallowed)
    /// 2. Then check if path is disallowed (disallowed_paths)
    /// 3. Default: allow all other paths
    pub fn is_path_allowed(&self, path: &Path) -> bool {
        use tracing::debug;
        
        debug!("Checking path access for: {:?}", path);
        
        // Canonicalize the path to resolve any .. or symlinks
        let canonical_path = match path.canonicalize() {
            Ok(p) => {
                debug!("Canonicalized path: {:?}", p);
                p
            },
            Err(e) => {
                debug!("Failed to canonicalize path {:?}: {}", path, e);
                // If we can't canonicalize, check if the parent exists
                if let Some(parent) = path.parent() {
                    match parent.canonicalize() {
                        Ok(parent_canonical) => parent_canonical.join(path.file_name().unwrap_or_default()),
                        Err(_) => {
                            debug!("Path and parent cannot be canonicalized, denying access");
                            return false;
                        }
                    }
                } else {
                    debug!("Path has no parent and cannot be canonicalized, denying access");
                    return false;
                }
            }
        };

        // STEP 1: Check if the path is explicitly allowed (highest priority)
        // If a path is in allowed_paths, it overrides any disallowed restriction
        for allowed in &self.allowed_paths {
            if canonical_path.starts_with(allowed) {
                debug!("Access EXPLICITLY ALLOWED: {:?} matches allowed rule: {:?}", canonical_path, allowed);
                return true;
            }
        }

        // STEP 2: Check if the path is disallowed
        // If no explicit allow rule matched, check disallow rules
        for disallowed in &self.disallowed_paths {
            debug!("Checking against disallowed path: {:?}", disallowed);
            if canonical_path.starts_with(disallowed) {
                debug!("Access DENIED: {:?} starts with disallowed rule: {:?}", canonical_path, disallowed);
                return false;
            }
        }

        // STEP 3: Default behavior - allow all other paths
        debug!("Access ALLOWED (default): {:?} not in any restriction list", canonical_path);
        true
    }

    /// Gets the list of disallowed paths for debugging/logging
    pub fn get_disallowed_paths(&self) -> &HashSet<PathBuf> {
        &self.disallowed_paths
    }

    /// Gets the list of allowed paths for debugging/logging
    pub fn get_allowed_paths(&self) -> &HashSet<PathBuf> {
        &self.allowed_paths
    }

    /// Validates if a command is safe to execute
    pub fn is_command_safe(&self, command: &str) -> bool {
        // Basic command safety checks
        let dangerous_commands = [
            "format", "del", "rmdir", "rd", "deltree",
            "shutdown", "restart", "reboot",
            "net user", "net localgroup",
            "reg delete", "reg add",
            "sc delete", "sc create",
        ];

        let command_lower = command.to_lowercase();
        
        for dangerous in &dangerous_commands {
            if command_lower.contains(dangerous) {
                return false;
            }
        }

        true
    }

    /// Sanitizes file content for safe writing
    pub fn sanitize_content(&self, content: &str) -> String {
        // Remove or escape potentially dangerous content
        content
            .replace('\0', "") // Remove null bytes
            .replace("\r\n", "\n") // Normalize line endings
            .replace('\r', "\n")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{ServerConfig, SecurityConfig, LoggingConfig};

    fn create_test_config() -> Config {
        Config {
            version: "1.0".to_string(),
            server: ServerConfig {
                host: "127.0.0.1".to_string(),
                port: 8080,
            },
            security: SecurityConfig {
                allowed_paths: vec![],
                disallowed_paths: vec!["C:\\Windows\\".to_string()],
                command_whitelist: vec!["echo".to_string(), "dir".to_string()],
                command_blacklist: Some(vec!["format".to_string(), "del".to_string()]),
                max_file_size_mb: 100,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                audit_file: "test.log".to_string(),
            },
        }
    }

    #[test]
    fn test_command_whitelist() {
        let security = SecurityManager::new(create_test_config());
        
        // Commands in whitelist should be allowed
        assert!(security.is_command_allowed("echo"));
        assert!(security.is_command_allowed("dir"));
        
        // Commands not in whitelist should be denied
        assert!(!security.is_command_allowed("git"));
        assert!(!security.is_command_allowed("npm"));
    }

    #[test]
    fn test_command_blacklist() {
        let security = SecurityManager::new(create_test_config());
        
        // Commands in blacklist should be denied even if in whitelist
        assert!(!security.is_command_allowed("format"));
        assert!(!security.is_command_allowed("del"));
    }

    #[test]
    fn test_file_size_limits() {
        let security = SecurityManager::new(create_test_config());
        
        // Files within limit should be allowed
        assert!(security.is_file_size_allowed(50 * 1024 * 1024)); // 50MB
        
        // Files exceeding limit should be denied
        assert!(!security.is_file_size_allowed(150 * 1024 * 1024)); // 150MB
    }


    #[test]
    fn test_path_validation() {
        let config = Config {
            version: "1.0".to_string(),
            server: ServerConfig {
                host: "127.0.0.1".to_string(),
                port: 8080,
            },
            security: SecurityConfig {
                allowed_paths: vec![],
                disallowed_paths: vec!["C:\\Windows\\".to_string()],
                command_whitelist: vec![],
                command_blacklist: None,
                max_file_size_mb: 100,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                audit_file: "test.log".to_string(),
            },
        };
        let security = SecurityManager::new(config);
        
        // Test with a relative path that should be allowed
        let temp_dir = std::env::temp_dir();
        assert!(security.is_path_allowed(&temp_dir));
    }
}
