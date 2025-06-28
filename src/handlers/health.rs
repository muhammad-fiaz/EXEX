use actix_web::{HttpResponse, Result};
use crate::models::HealthResponse;

/// Handles health check requests
pub async fn health_check() -> Result<HttpResponse> {
    let response = HealthResponse {
        status: "healthy".to_string(),
        service: "EXEX".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    };
    
    Ok(HttpResponse::Ok().json(response))
}
