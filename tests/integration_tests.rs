use std::env;
use tokio;
use reqwest;
use serde_json::json;

const BASE_URL: &str = "http://127.0.0.1:8080";

async fn make_request(
    client: &reqwest::Client,
    endpoint: &str,
    data: Option<serde_json::Value>,
) -> Result<reqwest::Response, reqwest::Error> {
    let url = format!("{}{}", BASE_URL, endpoint);
    
    match data {
        Some(body) => {
            client
                .post(&url)
                .header("Content-Type", "application/json")
                .json(&body)
                .send()
                .await
        }
        None => {
            client.get(&url).send().await
        }
    }
}

#[tokio::test]
#[ignore] // This test requires the server to be running
async fn test_health_endpoint() {
    let client = reqwest::Client::new();
    
    let response = make_request(&client, "/health", None).await.unwrap();
    assert_eq!(response.status(), 200);
    
    let body: serde_json::Value = response.json().await.unwrap();
    assert_eq!(body["status"], "healthy");
    assert_eq!(body["service"], "EXEX");
}

#[tokio::test]
#[ignore] // This test requires the server to be running
async fn test_read_test_data_file() {
    let client = reqwest::Client::new();
    
    // Read the test data file from our tests directory
    let test_data_path = env::current_dir()
        .unwrap()
        .join("tests")
        .join("test_data")
        .join("test_data.txt")
        .to_string_lossy()
        .to_string();
    
    let data = json!({
        "path": test_data_path
    });
    
    let response = make_request(&client, "/api/read", Some(data)).await.unwrap();
    assert_eq!(response.status(), 200);
    
    let body: serde_json::Value = response.json().await.unwrap();
    assert_eq!(body["success"], true);
    
    let content = body["content"].as_str().unwrap();
    assert!(content.contains("EXEX Test Data File"));
    assert!(content.contains("Testing EXEX functionality"));
}

#[tokio::test]
#[ignore] // This test requires the server to be running
async fn test_command_execution() {
    let client = reqwest::Client::new();
    
    let data = json!({
        "command": "echo Hello from integration test",
        "cwd": env::var("USERPROFILE").unwrap_or_else(|_| "C:\\Users".to_string())
    });
    
    let response = make_request(&client, "/api/exec", Some(data)).await.unwrap();
    assert_eq!(response.status(), 200);
    
    let body: serde_json::Value = response.json().await.unwrap();
    assert_eq!(body["success"], true);
    assert!(body["stdout"].as_str().unwrap().contains("Hello from integration test"));
}

#[tokio::test]
#[ignore] // This test requires the server to be running
async fn test_security_restrictions() {
    let client = reqwest::Client::new();
    
    // Try to read a restricted file
    let data = json!({
        "path": "C:\\Windows\\System32\\kernel32.dll"
    });
    
    let response = make_request(&client, "/api/read", Some(data)).await.unwrap();
    assert_eq!(response.status(), 403);
    
    let body: serde_json::Value = response.json().await.unwrap();
    assert!(body["error"].as_str().unwrap().contains("Access denied"));
}
