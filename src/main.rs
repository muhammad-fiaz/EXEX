mod config;
mod handlers;
mod models;
mod security;

use actix_web::{web, App, HttpServer, middleware::Logger};
use actix_cors::Cors;
use std::sync::Arc;
use tracing::info;

use crate::config::load_config;
use crate::handlers::{
    exec_command, read_file, write_file, health_check,
    scan_directory, delete_item, create_item, rename_item,
    open_application, shutdown_server
};
use crate::security::SecurityManager;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logging
    env_logger::init();
    
    info!("Starting EXEX - Local Execution Daemon");

    // Load configuration
    let config = load_config();
    let server_host = config.server.host.clone();
    let server_port = config.server.port;
    
    let security_manager = Arc::new(SecurityManager::new(config));

    info!("Loaded {} disallowed paths", security_manager.get_disallowed_paths().len());
    for path in security_manager.get_disallowed_paths() {
        info!("Disallowed: {}", path.display());
    }

    info!("Loaded {} allowed path exceptions", security_manager.get_allowed_paths().len());
    for path in security_manager.get_allowed_paths() {
        info!("Allowed exception: {}", path.display());
    }

    // Start HTTP server
    let bind_address = format!("{}:{}", server_host, server_port);
    info!("Starting server on http://{}", bind_address);

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(security_manager.clone()))
            .wrap(
                Cors::default()
                    .allow_any_origin()
                    .allow_any_method()
                    .allow_any_header()
                    .supports_credentials()
            )
            .wrap(Logger::default())
            .wrap(
                Cors::default()
                    .allow_any_origin()
                    .allow_any_method()
                    .allow_any_header()
                    .supports_credentials()
            )
            .service(
                web::scope("/api")
                    // Command execution
                    .route("/exec", web::post().to(exec_command))
                    // File operations
                    .route("/read", web::post().to(read_file))
                    .route("/write", web::post().to(write_file))
                    .route("/scan", web::post().to(scan_directory))
                    .route("/delete", web::post().to(delete_item))
                    .route("/create", web::post().to(create_item))
                    .route("/rename", web::post().to(rename_item))
                    // Application operations
                    .route("/open", web::post().to(open_application))
                    .route("/shutdown", web::post().to(shutdown_server))
            )
            .route("/health", web::get().to(health_check))
    })
    .bind(&bind_address)?
    .run()
    .await
}
