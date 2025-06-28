use actix_web::{web, HttpResponse, Result};
use std::path::PathBuf;
use std::process::Command;
use std::sync::Arc;

use tracing::{info, error, warn};

use crate::models::{ExecRequest, ExecResponse, ErrorResponse};
use crate::security::SecurityManager;

/// Handles command execution requests with enhanced security
pub async fn exec_command(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<ExecRequest>,
) -> Result<HttpResponse> {
    let command = req.command.clone();
    let args = req.args.clone();
    let cwd = req.cwd.clone();

    // Check command whitelist/blacklist
    if !security.is_command_allowed(&command) {
        warn!("Command execution denied: {}", command);
        return Ok(HttpResponse::Forbidden().json(ErrorResponse {
            error: format!("Command '{}' is not allowed by security policy", command),
        }));
    }

    // Validate working directory if provided
    if let Some(ref cwd_str) = cwd {
        let cwd_path = PathBuf::from(cwd_str);
        if !security.is_path_allowed(&cwd_path) {
            warn!("Working directory access denied: {}", cwd_str);
            return Ok(HttpResponse::Forbidden().json(ErrorResponse {
                error: format!("Access denied to directory: {}", cwd_str),
            }));
        }
    }

    info!("Executing command: '{}' with args: {:?} in {:?}", command, args, cwd);

    // Execute command in a blocking thread
    let result = web::block(move || {
        let mut cmd = if let Some(ref command_args) = args {
            // If args are provided separately, use them directly
            let mut c = Command::new(&command);
            c.args(command_args);
            c
        } else {
            // Backward compatibility: if no args provided, use shell execution
            if cfg!(target_os = "windows") {
                let mut c = Command::new("cmd");
                c.args(["/C", &command]);
                c
            } else {
                let mut c = Command::new("sh");
                c.args(["-c", &command]);
                c
            }
        };

        if let Some(cwd_str) = cwd {
            cmd.current_dir(cwd_str);
        }

        cmd.output()
    })
    .await;

    match result {
        Ok(Ok(output)) => {
            let response = ExecResponse {
                success: output.status.success(),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
                exit_code: output.status.code(),
            };
            info!("Command executed successfully with exit code: {:?}", response.exit_code);
            Ok(HttpResponse::Ok().json(response))
        }
        Ok(Err(io_error)) => {
            error!("IO error executing command: {}", io_error);
            Ok(HttpResponse::InternalServerError().json(ErrorResponse {
                error: format!("IO error executing command: {}", io_error),
            }))
        }
        Err(e) => {
            error!("Failed to execute command: {}", e);
            Ok(HttpResponse::InternalServerError().json(ErrorResponse {
                error: format!("Failed to execute command: {}", e),
            }))
        }
    }
}
