use exex::models::*;

#[test]
fn test_exec_request_serialization() {
    let request = ExecRequest {
        command: "echo hello".to_string(),
        cwd: Some("C:/Users".to_string()),
    };
    
    let json = serde_json::to_string(&request).unwrap();
    assert!(json.contains("echo hello"));
    assert!(json.contains("C:/Users"));
}

#[test]
fn test_exec_response_serialization() {
    let response = ExecResponse {
        success: true,
        stdout: "Hello World".to_string(),
        stderr: "".to_string(),
        exit_code: Some(0),
    };
    
    let json = serde_json::to_string(&response).unwrap();
    assert!(json.contains("Hello World"));
    assert!(json.contains("true"));
}

#[test]
fn test_read_write_request_serialization() {
    let read_req = ReadRequest {
        path: "test.txt".to_string(),
    };
    
    let write_req = WriteRequest {
        path: "test.txt".to_string(),
        content: "test content".to_string(),
    };
    
    let read_json = serde_json::to_string(&read_req).unwrap();
    let write_json = serde_json::to_string(&write_req).unwrap();
    
    assert!(read_json.contains("test.txt"));
    assert!(write_json.contains("test content"));
}

#[test]
fn test_error_response() {
    let error = ErrorResponse {
        error: "Access denied".to_string(),
    };
    
    let json = serde_json::to_string(&error).unwrap();
    assert!(json.contains("Access denied"));
}
