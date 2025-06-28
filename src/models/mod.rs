use serde::{Deserialize, Serialize};

/// Configuration structure for EXEX daemon
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Config {
    pub version: String,
    pub server: ServerConfig,
    pub security: SecurityConfig,
    pub logging: LoggingConfig,
}

/// Server configuration
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

/// Security configuration
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SecurityConfig {
    pub allowed_paths: Vec<String>,
    pub disallowed_paths: Vec<String>,
    pub command_whitelist: Vec<String>,
    pub command_blacklist: Option<Vec<String>>,
    pub max_file_size_mb: u64,
}

/// Logging configuration
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct LoggingConfig {
    pub level: String,
    pub audit_file: String,
}

/// Legacy config support for backward compatibility
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct LegacyConfig {
    pub version: String,
    pub exex_project: Option<String>,
    pub created: Option<String>,
    pub disallowed_paths: Vec<String>,
    pub allowed_paths: Vec<String>,
}

/// Request structure for command execution
#[derive(Debug, Deserialize)]
pub struct ExecRequest {
    pub command: String,
    pub args: Option<Vec<String>>,
    pub cwd: Option<String>,
}

/// Request structure for file reading
#[derive(Debug, Deserialize)]
pub struct ReadRequest {
    pub path: String,
}

/// Request structure for file writing
#[derive(Debug, Deserialize)]
pub struct WriteRequest {
    pub path: String,
    pub content: String,
}

/// Response structure for command execution
#[derive(Debug, Serialize)]
pub struct ExecResponse {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
    pub exit_code: Option<i32>,
}

/// Response structure for file reading
#[derive(Debug, Serialize)]
pub struct ReadResponse {
    pub success: bool,
    pub content: Option<String>,
    pub error: Option<String>,
}

/// Response structure for file writing
#[derive(Debug, Serialize)]
pub struct WriteResponse {
    pub success: bool,
    pub error: Option<String>,
}

/// Generic error response structure
#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

/// Health check response structure
#[derive(Debug, Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub service: String,
    pub version: String,
}

/// Request structure for opening applications
#[derive(Debug, Deserialize)]
pub struct OpenAppRequest {
    pub application: String,
    pub args: Option<Vec<String>>,
    pub cwd: Option<String>,
}

/// Request structure for scanning directories
#[derive(Debug, Deserialize)]
pub struct ScanRequest {
    pub path: String,
    pub recursive: Option<bool>,
    pub include_hidden: Option<bool>,
}

/// Request structure for delete operations
#[derive(Debug, Deserialize)]
pub struct DeleteRequest {
    pub path: String,
    pub recursive: Option<bool>,
}

/// Request structure for create operations
#[derive(Debug, Deserialize)]
pub struct CreateRequest {
    pub path: String,
    pub is_directory: bool,
    pub content: Option<String>, // For files
}

/// Request structure for rename/move operations
#[derive(Debug, Deserialize)]
pub struct RenameRequest {
    pub from_path: String,
    pub to_path: String,
}

/// File/Directory information
#[derive(Debug, Serialize, Clone)]
pub struct FileInfo {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub size: Option<u64>,
    pub modified: Option<String>,
    pub created: Option<String>,
    pub permissions: Option<String>,
}

/// Response structure for opening applications
#[derive(Debug, Serialize)]
pub struct OpenAppResponse {
    pub success: bool,
    pub pid: Option<u32>,
    pub error: Option<String>,
}

/// Response structure for scanning directories
#[derive(Debug, Serialize)]
pub struct ScanResponse {
    pub success: bool,
    pub items: Option<Vec<FileInfo>>,
    pub total_count: Option<usize>,
    pub error: Option<String>,
}

/// Response structure for delete operations
#[derive(Debug, Serialize)]
pub struct DeleteResponse {
    pub success: bool,
    pub deleted_count: Option<usize>,
    pub error: Option<String>,
}

/// Response structure for create operations
#[derive(Debug, Serialize)]
pub struct CreateResponse {
    pub success: bool,
    pub created_path: Option<String>,
    pub error: Option<String>,
}

/// Response structure for rename operations
#[derive(Debug, Serialize)]
pub struct RenameResponse {
    pub success: bool,
    pub old_path: Option<String>,
    pub new_path: Option<String>,
    pub error: Option<String>,
}

/// Response structure for shutdown operation
#[derive(Debug, Serialize)]
pub struct ShutdownResponse {
    pub success: bool,
    pub message: String,
    pub shutdown_in_seconds: Option<u32>,
}
