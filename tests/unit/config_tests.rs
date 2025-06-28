use exex::config::{load_config, get_default_config, validate_config};

#[test]
fn test_default_config() {
    let config = get_default_config();
    assert!(!config.disallowed_paths.is_empty());
    assert!(config.disallowed_paths.contains(&"C:/Windows/".to_string()));
    assert!(config.disallowed_paths.contains(&"C:/Program Files/".to_string()));
}

#[test]
fn test_config_validation() {
    let valid_config = get_default_config();
    assert!(validate_config(&valid_config).is_ok());
    
    let invalid_config = exex::models::Config {
        disallowed_paths: vec![],
    };
    assert!(validate_config(&invalid_config).is_err());
    
    let invalid_config2 = exex::models::Config {
        disallowed_paths: vec!["".to_string()],
    };
    assert!(validate_config(&invalid_config2).is_err());
}
