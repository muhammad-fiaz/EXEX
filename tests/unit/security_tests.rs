use exex::security::SecurityManager;
use exex::models::Config;
use std::path::Path;

#[test]
fn test_security_manager_creation() {
    let config = Config {
        disallowed_paths: vec!["C:/Windows/".to_string()],
    };
    let security = SecurityManager::new(config);
    assert_eq!(security.get_disallowed_paths().len(), 1);
}

#[test]
fn test_command_safety() {
    let config = Config {
        disallowed_paths: vec![],
    };
    let security = SecurityManager::new(config);
    
    // Safe commands
    assert!(security.is_command_safe("echo hello"));
    assert!(security.is_command_safe("dir"));
    assert!(security.is_command_safe("ls -la"));
    
    // Dangerous commands
    assert!(!security.is_command_safe("format c:"));
    assert!(!security.is_command_safe("del /f /q *"));
    assert!(!security.is_command_safe("shutdown /s"));
    assert!(!security.is_command_safe("reg delete HKLM"));
}

#[test]
fn test_content_sanitization() {
    let config = Config {
        disallowed_paths: vec![],
    };
    let security = SecurityManager::new(config);
    
    let content = "Hello\0World\r\nTest\rLine";
    let sanitized = security.sanitize_content(content);
    assert_eq!(sanitized, "HelloWorld\nTest\nLine");
    
    // Test that normal content is preserved
    let normal_content = "Hello World\nLine 2\nLine 3";
    let sanitized_normal = security.sanitize_content(normal_content);
    assert_eq!(sanitized_normal, normal_content);
}
