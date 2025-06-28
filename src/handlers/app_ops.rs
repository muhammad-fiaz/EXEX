use actix_web::{web, HttpResponse, Result};
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::path::PathBuf;
use tracing::{info, error};

use crate::models::{OpenAppRequest, OpenAppResponse, ShutdownResponse};
use crate::security::SecurityManager;

/// Handles application launch requests
pub async fn open_application(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<OpenAppRequest>,
) -> Result<HttpResponse> {
    let app_path = PathBuf::from(&req.application);

    // Check if the application path is allowed
    if !security.is_path_allowed(&app_path) {
        return Ok(HttpResponse::Forbidden().json(OpenAppResponse {
            success: false,
            pid: None,
            error: Some(format!("Access denied to application: {}", req.application)),
        }));
    }

    // Basic command safety check
    if !security.is_command_safe(&req.application) {
        return Ok(HttpResponse::Forbidden().json(OpenAppResponse {
            success: false,
            pid: None,
            error: Some(format!("Application deemed unsafe: {}", req.application)),
        }));
    }

    info!("Opening application: {}", req.application);

    let mut command = Command::new(&req.application);
    
    // Add arguments if provided
    if let Some(args) = &req.args {
        command.args(args);
    }

    // Set working directory if provided
    if let Some(cwd) = &req.cwd {
        let cwd_path = PathBuf::from(cwd);
        if security.is_path_allowed(&cwd_path) {
            command.current_dir(cwd);
        } else {
            return Ok(HttpResponse::Forbidden().json(OpenAppResponse {
                success: false,
                pid: None,
                error: Some(format!("Access denied to working directory: {}", cwd)),
            }));
        }
    }

    // Configure process to run independently
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    match command.spawn() {
        Ok(child) => {
            let pid = child.id();
            info!("Successfully launched application: {} (PID: {})", req.application, pid);
            Ok(HttpResponse::Ok().json(OpenAppResponse {
                success: true,
                pid: Some(pid),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to launch application {}: {}", req.application, e);
            Ok(HttpResponse::Ok().json(OpenAppResponse {
                success: false,
                pid: None,
                error: Some(format!("Failed to launch application: {}", e)),
            }))
        }
    }
}

/// Handles server shutdown requests
pub async fn shutdown_server() -> Result<HttpResponse> {
    info!("Received shutdown request");
    
    // Return immediate response before shutting down
    let response = HttpResponse::Ok().json(ShutdownResponse {
        success: true,
        message: "Server shutdown initiated".to_string(),
        shutdown_in_seconds: Some(2),
    });

    // Schedule shutdown in background
    tokio::spawn(async {
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        info!("Shutting down EXEX server...");
        std::process::exit(0);
    });

    Ok(response)
}
