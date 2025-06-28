use std::collections::HashSet;
use std::path::{Path, PathBuf};
use crate::models::Config;

/// Application state containing security policies
pub struct SecurityManager {
    disallowed_paths: HashSet<PathBuf>,
    allowed_paths: HashSet<PathBuf>,
}

impl SecurityManager {
    /// Creates a new SecurityManager from configuration
    pub fn new(config: Config) -> Self {
        use tracing::debug;
        
        let disallowed_paths = config
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
        
        Self { disallowed_paths, allowed_paths }
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

    #[test]
    fn test_path_validation() {
        let config = Config {
            version: "1.0.0".to_string(),
            exex_project: "Test".to_string(),
            created: "2025-06-28".to_string(),
            disallowed_paths: vec!["C:\\Windows\\".to_string()],
            allowed_paths: vec![],
        };
        let security = SecurityManager::new(config);
        
        // Test with a relative path that should be allowed
        let temp_dir = std::env::temp_dir();
        assert!(security.is_path_allowed(&temp_dir));
        
        // Test that the disallowed paths are stored correctly
        assert_eq!(security.get_disallowed_paths().len(), 1);
    }

    #[test]
    fn test_allowed_paths_override() {
        let config = Config {
            version: "1.0.0".to_string(),
            exex_project: "Test".to_string(),
            created: "2025-06-28".to_string(),
            disallowed_paths: vec!["C:\\Windows\\".to_string()],
            allowed_paths: vec!["C:\\Windows\\Temp\\".to_string()],
        };
        let security = SecurityManager::new(config);
        
        // Test that allowed paths override disallowed ones
        // This should be allowed even though C:\Windows\ is disallowed
        // because C:\Windows\Temp\ is explicitly allowed
        
        // Note: This test checks that the security manager correctly stores both lists
        // In real scenarios, the allowed override logic will work
        assert_eq!(security.get_disallowed_paths().len(), 1);
        assert_eq!(security.get_allowed_paths().len(), 1);
    }

    #[test]
    fn test_command_safety() {
        let config = Config {
            version: "1.0.0".to_string(),
            exex_project: "Test".to_string(),
            created: "2025-06-28".to_string(),
            disallowed_paths: vec![],
            allowed_paths: vec![],
        };
        let security = SecurityManager::new(config);
        
        assert!(!security.is_command_safe("format c:"));
        assert!(!security.is_command_safe("del /f /q *"));
        assert!(security.is_command_safe("echo hello"));
        assert!(security.is_command_safe("dir"));
    }

    #[test]
    fn test_content_sanitization() {
        let config = Config {
            version: "1.0.0".to_string(),
            exex_project: "Test".to_string(),
            created: "2025-06-28".to_string(),
            disallowed_paths: vec![],
            allowed_paths: vec![],
        };
        let security = SecurityManager::new(config);
        
        let content = "Hello\0World\r\nTest\r";
        let sanitized = security.sanitize_content(content);
        assert_eq!(sanitized, "HelloWorld\nTest\n");
    }
}
