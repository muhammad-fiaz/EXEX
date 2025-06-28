use actix_web::{web, HttpResponse, Result};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::SystemTime;
use tokio::fs;
use tracing::{info, error};

use crate::models::{
    ReadRequest, WriteRequest, ReadResponse, WriteResponse,
    ScanRequest, ScanResponse, DeleteRequest, DeleteResponse,
    CreateRequest, CreateResponse, RenameRequest, RenameResponse,
    FileInfo
};
use crate::security::SecurityManager;

/// Handles file reading requests
pub async fn read_file(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<ReadRequest>,
) -> Result<HttpResponse> {
    let path = PathBuf::from(&req.path);

    if !security.is_path_allowed(&path) {
        return Ok(HttpResponse::Forbidden().json(ReadResponse {
            success: false,
            content: None,
            error: Some(format!("Access denied to file: {}", req.path)),
        }));
    }

    info!("Reading file: {}", req.path);

    match fs::read_to_string(&path).await {
        Ok(content) => {
            info!("Successfully read file: {} ({} bytes)", req.path, content.len());
            Ok(HttpResponse::Ok().json(ReadResponse {
                success: true,
                content: Some(content),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to read file {}: {}", req.path, e);
            Ok(HttpResponse::Ok().json(ReadResponse {
                success: false,
                content: None,
                error: Some(format!("Failed to read file: {}", e)),
            }))
        }
    }
}

/// Handles file writing requests
pub async fn write_file(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<WriteRequest>,
) -> Result<HttpResponse> {
    let path = PathBuf::from(&req.path);

    if !security.is_path_allowed(&path) {
        return Ok(HttpResponse::Forbidden().json(WriteResponse {
            success: false,
            error: Some(format!("Access denied to file: {}", req.path)),
        }));
    }

    // Sanitize content
    let sanitized_content = security.sanitize_content(&req.content);

    info!("Writing to file: {} ({} bytes)", req.path, sanitized_content.len());

    // Create parent directories if they don't exist
    if let Some(parent) = path.parent() {
        if let Err(e) = fs::create_dir_all(parent).await {
            error!("Failed to create directories for {}: {}", req.path, e);
            return Ok(HttpResponse::Ok().json(WriteResponse {
                success: false,
                error: Some(format!("Failed to create directories: {}", e)),
            }));
        }
    }

    match fs::write(&path, &sanitized_content).await {
        Ok(_) => {
            info!("Successfully wrote file: {}", req.path);
            Ok(HttpResponse::Ok().json(WriteResponse {
                success: true,
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to write file {}: {}", req.path, e);
            Ok(HttpResponse::Ok().json(WriteResponse {
                success: false,
                error: Some(format!("Failed to write file: {}", e)),
            }))
        }
    }
}

/// Handles directory scanning requests
pub async fn scan_directory(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<ScanRequest>,
) -> Result<HttpResponse> {
    
    let path = PathBuf::from(&req.path);

    if !security.is_path_allowed(&path) {
        return Ok(HttpResponse::Forbidden().json(ScanResponse {
            success: false,
            items: None,
            total_count: None,
            error: Some(format!("Access denied to directory: {}", req.path)),
        }));
    }

    info!("Scanning directory: {}", req.path);

    let mut items = Vec::new();
    let recursive = req.recursive.unwrap_or(false);
    let include_hidden = req.include_hidden.unwrap_or(false);

    let scan_result = if recursive {
        scan_directory_recursive(&path, include_hidden, &security).await
    } else {
        scan_directory_single(&path, include_hidden).await
    };

    match scan_result {
        Ok(mut scanned_items) => {
            items.append(&mut scanned_items);
            info!("Successfully scanned directory: {} ({} items)", req.path, items.len());
            Ok(HttpResponse::Ok().json(ScanResponse {
                success: true,
                items: Some(items.clone()),
                total_count: Some(items.len()),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to scan directory {}: {}", req.path, e);
            Ok(HttpResponse::Ok().json(ScanResponse {
                success: false,
                items: None,
                total_count: None,
                error: Some(format!("Failed to scan directory: {}", e)),
            }))
        }
    }
}

async fn scan_directory_single(path: &PathBuf, include_hidden: bool) -> Result<Vec<FileInfo>, Box<dyn std::error::Error>> {
    let mut items = Vec::new();
    let mut entries = fs::read_dir(path).await?;

    while let Some(entry) = entries.next_entry().await? {
        let metadata = entry.metadata().await?;
        let file_name = entry.file_name().to_string_lossy().to_string();
        
        // Skip hidden files if not requested
        if !include_hidden && file_name.starts_with('.') {
            continue;
        }

        let file_info = FileInfo {
            name: file_name,
            path: entry.path().to_string_lossy().to_string(),
            is_directory: metadata.is_dir(),
            size: if metadata.is_file() { Some(metadata.len()) } else { None },
            modified: metadata.modified().ok().and_then(|t| 
                t.duration_since(SystemTime::UNIX_EPOCH).ok().map(|d| d.as_secs().to_string())
            ),
            created: metadata.created().ok().and_then(|t| 
                t.duration_since(SystemTime::UNIX_EPOCH).ok().map(|d| d.as_secs().to_string())
            ),
            permissions: Some(format!("{:?}", metadata.permissions())),
        };
        
        items.push(file_info);
    }

    Ok(items)
}

async fn scan_directory_recursive(
    path: &PathBuf, 
    include_hidden: bool, 
    security: &Arc<SecurityManager>
) -> Result<Vec<FileInfo>, Box<dyn std::error::Error>> {
    let mut items = Vec::new();
    let mut stack = vec![path.clone()];

    while let Some(current_path) = stack.pop() {
        // Check if we still have permission for subdirectories
        if !security.is_path_allowed(&current_path) {
            continue;
        }

        if let Ok(single_items) = scan_directory_single(&current_path, include_hidden).await {
            for item in single_items {
                if item.is_directory {
                    stack.push(PathBuf::from(&item.path));
                }
                items.push(item);
            }
        }
    }

    Ok(items)
}

/// Handles file/directory deletion requests
pub async fn delete_item(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<DeleteRequest>,
) -> Result<HttpResponse> {
    let path = PathBuf::from(&req.path);

    if !security.is_path_allowed(&path) {
        return Ok(HttpResponse::Forbidden().json(DeleteResponse {
            success: false,
            deleted_count: None,
            error: Some(format!("Access denied to delete: {}", req.path)),
        }));
    }

    info!("Deleting item: {}", req.path);

    let recursive = req.recursive.unwrap_or(false);
    let mut deleted_count = 0;

    let result = if path.is_file() {
        match fs::remove_file(&path).await {
            Ok(_) => {
                deleted_count = 1;
                Ok(())
            }
            Err(e) => Err(e)
        }
    } else if path.is_dir() {
        if recursive {
            match fs::remove_dir_all(&path).await {
                Ok(_) => {
                    deleted_count = 1; // We don't count individual files in recursive delete
                    Ok(())
                }
                Err(e) => Err(e)
            }
        } else {
            match fs::remove_dir(&path).await {
                Ok(_) => {
                    deleted_count = 1;
                    Ok(())
                }
                Err(e) => Err(e)
            }
        }
    } else {
        Err(std::io::Error::new(std::io::ErrorKind::NotFound, "Path not found"))
    };

    match result {
        Ok(_) => {
            info!("Successfully deleted: {}", req.path);
            Ok(HttpResponse::Ok().json(DeleteResponse {
                success: true,
                deleted_count: Some(deleted_count),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to delete {}: {}", req.path, e);
            Ok(HttpResponse::Ok().json(DeleteResponse {
                success: false,
                deleted_count: None,
                error: Some(format!("Failed to delete: {}", e)),
            }))
        }
    }
}

/// Handles file/directory creation requests
pub async fn create_item(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<CreateRequest>,
) -> Result<HttpResponse> {
    let path = PathBuf::from(&req.path);

    if !security.is_path_allowed(&path) {
        return Ok(HttpResponse::Forbidden().json(CreateResponse {
            success: false,
            created_path: None,
            error: Some(format!("Access denied to create: {}", req.path)),
        }));
    }

    info!("Creating item: {} (directory: {})", req.path, req.is_directory);

    // Check if item already exists
    if path.exists() {
        return Ok(HttpResponse::Ok().json(CreateResponse {
            success: false,
            created_path: None,
            error: Some(format!("Item already exists: {}", req.path)),
        }));
    }

    let result = if req.is_directory {
        fs::create_dir_all(&path).await
    } else {
        // Create parent directories if needed
        if let Some(parent) = path.parent() {
            if let Err(e) = fs::create_dir_all(parent).await {
                error!("Failed to create parent directories for {}: {}", req.path, e);
                return Ok(HttpResponse::Ok().json(CreateResponse {
                    success: false,
                    created_path: None,
                    error: Some(format!("Failed to create parent directories: {}", e)),
                }));
            }
        }

        // Create file with content
        let content = req.content.as_deref().unwrap_or("");
        let sanitized_content = security.sanitize_content(content);
        fs::write(&path, sanitized_content).await
    };

    match result {
        Ok(_) => {
            info!("Successfully created: {}", req.path);
            Ok(HttpResponse::Ok().json(CreateResponse {
                success: true,
                created_path: Some(path.to_string_lossy().to_string()),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to create {}: {}", req.path, e);
            Ok(HttpResponse::Ok().json(CreateResponse {
                success: false,
                created_path: None,
                error: Some(format!("Failed to create: {}", e)),
            }))
        }
    }
}

/// Handles file/directory rename/move requests
pub async fn rename_item(
    security: web::Data<Arc<SecurityManager>>,
    req: web::Json<RenameRequest>,
) -> Result<HttpResponse> {
    let from_path = PathBuf::from(&req.from_path);
    let to_path = PathBuf::from(&req.to_path);

    // Check permissions for both source and destination
    if !security.is_path_allowed(&from_path) {
        return Ok(HttpResponse::Forbidden().json(RenameResponse {
            success: false,
            old_path: None,
            new_path: None,
            error: Some(format!("Access denied to source path: {}", req.from_path)),
        }));
    }

    if !security.is_path_allowed(&to_path) {
        return Ok(HttpResponse::Forbidden().json(RenameResponse {
            success: false,
            old_path: None,
            new_path: None,
            error: Some(format!("Access denied to destination path: {}", req.to_path)),
        }));
    }

    info!("Renaming/moving: {} -> {}", req.from_path, req.to_path);

    // Check if source exists
    if !from_path.exists() {
        return Ok(HttpResponse::Ok().json(RenameResponse {
            success: false,
            old_path: None,
            new_path: None,
            error: Some(format!("Source path does not exist: {}", req.from_path)),
        }));
    }

    // Check if destination already exists
    if to_path.exists() {
        return Ok(HttpResponse::Ok().json(RenameResponse {
            success: false,
            old_path: None,
            new_path: None,
            error: Some(format!("Destination path already exists: {}", req.to_path)),
        }));
    }

    // Create parent directory of destination if needed
    if let Some(parent) = to_path.parent() {
        if let Err(e) = fs::create_dir_all(parent).await {
            error!("Failed to create parent directories for {}: {}", req.to_path, e);
            return Ok(HttpResponse::Ok().json(RenameResponse {
                success: false,
                old_path: None,
                new_path: None,
                error: Some(format!("Failed to create parent directories: {}", e)),
            }));
        }
    }

    match fs::rename(&from_path, &to_path).await {
        Ok(_) => {
            info!("Successfully renamed/moved: {} -> {}", req.from_path, req.to_path);
            Ok(HttpResponse::Ok().json(RenameResponse {
                success: true,
                old_path: Some(req.from_path.clone()),
                new_path: Some(req.to_path.clone()),
                error: None,
            }))
        }
        Err(e) => {
            error!("Failed to rename/move {} -> {}: {}", req.from_path, req.to_path, e);
            Ok(HttpResponse::Ok().json(RenameResponse {
                success: false,
                old_path: None,
                new_path: None,
                error: Some(format!("Failed to rename/move: {}", e)),
            }))
        }
    }
}
