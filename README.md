<p align="center">
  <img src="https://github.com/user-attachments/assets/3df5157a-e2a0-40a3-9e9e-b402f4b642b5" alt="EXEX Logo" width="400"/>
</p>

<h1 align="center">EXEX - Local Execution Daemon</h1>


A secure, modular, and comprehensive local API server built with Rust and Actix-Web that enables frontend applications to perform safe file operations, command execution, directory management, and application launching on the user's computer through HTTP APIs.

## 📁 Complete Project Structure

```
exex/
├── Cargo.toml                    # Rust package configuration
├── Cargo.lock                    # Dependency lock file
├── README.md                     # Complete documentation (this file)
├── run-tests.ps1                 # Test runner script
│
├── src/                          # Source code
│   ├── main.rs                   # Application entry point and server setup
│   ├── config/                   # Configuration management
│   │   └── mod.rs               # Dynamic config creation, cross-platform paths
│   ├── handlers/                 # HTTP request handlers
│   │   ├── mod.rs               # Handler module exports
│   │   ├── health.rs            # Health check endpoint
│   │   ├── exec.rs              # Command execution handler
│   │   ├── file_ops.rs          # File operations (read/write/scan/create/delete/rename)
│   │   └── app_ops.rs           # Application operations (open/shutdown)
│   ├── models/                   # Data structures and API models
│   │   └── mod.rs               # Request/response types, Config struct
│   └── security/                 # Security and validation
│       └── mod.rs               # SecurityManager, path validation logic
│
├── tests/                        # Test suite
│   ├── integration/              # Integration tests
│   │   └── api_tests.rs         # End-to-end API testing
│   ├── unit/                     # Unit tests
│   │   ├── config_tests.rs      # Configuration testing
│   │   ├── security_tests.rs    # Security validation testing
│   │   └── mod.rs               # Test module organization
│   ├── test_data/                # Test data files
│   │   ├── sample.txt           # Sample text file for testing
│   │   ├── test_input.json      # JSON test data
│   │   └── binary_file.dat      # Binary file for testing
│   ├── console-test-suite.ps1    # Comprehensive PowerShell API test suite
│   ├── cross-platform-config-test.ps1  # Config validation tests
│   ├── allowed-paths-test.ps1    # Security model validation tests
│   └── simple-operations-test.ps1       # Individual operation tests
│
├── examples/                     # Usage examples and client code
│   └── client-example.js         # JavaScript client examples
│
└── target/                       # Rust build artifacts (auto-generated)
    └── debug/
        └── exex.exe             # Compiled executable
```

## 🗂️ Source Code Structure

### Core Application (`src/main.rs`)

- **Server Setup**: Actix-Web server configuration and startup
- **Route Registration**: All API endpoints registration
- **Config Loading**: Dynamic configuration initialization
- **Security Logging**: Startup logging of allowed/disallowed paths
- **CORS Configuration**: Cross-origin request handling

### Configuration Management (`src/config/mod.rs`)

- **Dynamic Config Creation**: Auto-creates config in user's AppData directory
- **Cross-Platform Paths**: Windows, macOS, Linux support
- **Config Validation**: Structure validation with fallback to defaults
- **Version Management**: Config versioning and migration support

### Request Handlers (`src/handlers/`)

- **Health Check** (`health.rs`): Service status and version info
- **Command Execution** (`exec.rs`): Safe system command execution
- **File Operations** (`file_ops.rs`): Read, write, create, delete, rename, scan
- **Application Operations** (`app_ops.rs`): Open applications, server shutdown

### Data Models (`src/models/mod.rs`)

- **Config Struct**: Application configuration structure
- **Request Types**: All API request payload structures
- **Response Types**: Standardized API response structures
- **Error Handling**: Comprehensive error response models

### Security Layer (`src/security/mod.rs`)

- **SecurityManager**: Central security validation
- **Path Validation**: Canonicalization and traversal prevention
- **Allow/Disallow Logic**: Priority-based path access control
- **Platform Defaults**: OS-specific security defaults

## ⚙️ Configuration System

### Dynamic Configuration

EXEX automatically creates its configuration file at the appropriate location for your operating system:

- **Windows**: `%LOCALAPPDATA%\EXEX\exex.config.json`
- **macOS**: `~/Library/Application Support/EXEX/exex.config.json`
- **Linux**: `~/.local/share/EXEX/exex.config.json`

### Configuration Structure

```json
{
  "version": "1.0",
  "server": {
    "host": "127.0.0.1",
    "port": 8080
  },
  "security": {
    "allowed_paths": [
      "C:\\Users\\username\\Documents",
      "C:\\Users\\username\\Downloads"
    ],
    "disallowed_paths": [
      "C:\\Windows\\System32",
      "C:\\Program Files"
    ],
    "command_whitelist": [
      "git",
      "npm",
      "node",
      "echo"
    ],
    "command_blacklist": [
      "format",
      "del",
      "rmdir"
    ],
    "max_file_size_mb": 100
  },
  "logging": {
    "level": "info",
    "audit_file": "exex.audit.log"
  }
}
```

### Security Model

The security system follows a priority-based approach:

1. **Allowed Paths** (Highest Priority): If specified, ONLY these paths are accessible
2. **Disallowed Paths** (Medium Priority): If no allowed_paths, these paths are blocked
3. **Default Allow** (Lowest Priority): If neither specified, all paths are accessible

**Example Security Scenarios:**

```json
// Scenario 1: Restrictive (Only allow specific directories)
{
  "security": {
    "allowed_paths": ["C:\\Users\\username\\Documents", "C:\\Users\\username\\Pictures"]
  }
}
// Result: Only Documents and Pictures directories are accessible

// Scenario 2: Permissive with exceptions (Block only specific directories)
{
  "security": {
    "disallowed_paths": ["C:\\Windows", "C:\\Program Files"]
  }
}
// Result: All paths except Windows and Program Files are accessible

// Scenario 3: Default (No restrictions)
{
  "security": {}
}
// Result: All paths are accessible (use with caution)
```

### Cross-Platform Default Restrictions

**Windows**:
- `C:/Windows/`, `C:/Program Files/`, `C:/Windows/System32/`
- `C:/Users/*/AppData/Roaming/`, `C:/ProgramData/`

**macOS**:
- `/System/`, `/Library/`, `/Applications/`, `/usr/`, `/private/`

**Linux**:
- `/etc/`, `/boot/`, `/sys/`, `/proc/`, `/dev/`, `/root/`, `/usr/bin/`

## 🚀 API Endpoints

### Health Check

**GET** `/health`

Returns server status and version information.

**Response:**
```json
{
  "status": "OK",
  "version": "1.0.0",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### File Operations

#### Read File

**POST** `/api/file/read`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\file.txt"
}
```

**Response:**
```json
{
  "success": true,
  "content": "File content here...",
  "size": 1024,
  "modified": "2024-01-01T12:00:00Z"
}
```

#### Write File

**POST** `/api/file/write`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\newfile.txt",
  "content": "Content to write",
  "append": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "File written successfully",
  "bytes_written": 16
}
```

#### Create File

**POST** `/api/file/create`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\newfile.txt",
  "content": "Initial content"
}
```

**Response:**
```json
{
  "success": true,
  "message": "File created successfully"
}
```

#### Delete File

**POST** `/api/file/delete`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\oldfile.txt"
}
```

**Response:**
```json
{
  "success": true,
  "message": "File deleted successfully"
}
```

#### Rename File

**POST** `/api/file/rename`

**Request:**
```json
{
  "old_path": "C:\\Users\\username\\Documents\\oldname.txt",
  "new_path": "C:\\Users\\username\\Documents\\newname.txt"
}
```

**Response:**
```json
{
  "success": true,
  "message": "File renamed successfully"
}
```

#### Scan Directory

**POST** `/api/file/scan`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents",
  "recursive": true,
  "include_hidden": false
}
```

**Response:**
```json
{
  "success": true,
  "files": [
    {
      "name": "document.txt",
      "path": "C:\\Users\\username\\Documents\\document.txt",
      "size": 1024,
      "is_directory": false,
      "modified": "2024-01-01T12:00:00Z"
    }
  ],
  "directories": [
    {
      "name": "subfolder",
      "path": "C:\\Users\\username\\Documents\\subfolder",
      "is_directory": true,
      "modified": "2024-01-01T12:00:00Z"
    }
  ]
}
```

### Directory Operations

#### Create Directory

**POST** `/api/directory/create`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\NewFolder"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Directory created successfully"
}
```

#### Delete Directory

**POST** `/api/directory/delete`

**Request:**
```json
{
  "path": "C:\\Users\\username\\Documents\\OldFolder",
  "recursive": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Directory deleted successfully"
}
```

#### Rename Directory

**POST** `/api/directory/rename`

**Request:**
```json
{
  "old_path": "C:\\Users\\username\\Documents\\OldFolderName",
  "new_path": "C:\\Users\\username\\Documents\\NewFolderName"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Directory renamed successfully"
}
```

### Command Execution

#### Execute Command

**POST** `/api/exec`

**Request:**
```json
{
  "command": "git",
  "args": ["status", "--porcelain"],
  "cwd": "C:\\Users\\username\\Documents\\MyProject"
}
```

**Alternative (Backward Compatible):**
```json
{
  "command": "git status --porcelain",
  "cwd": "C:\\Users\\username\\Documents\\MyProject"
}
```

**Response:**
```json
{
  "success": true,
  "stdout": "Directory listing output...",
  "stderr": "",
  "exit_code": 0
}
```

**Parameters:**
- `command` (string, required): The command or executable to run
- `args` (array of strings, optional): Command arguments as separate array elements
- `cwd` (string, optional): Working directory for command execution

**Note:** If `args` is provided, the command will be executed directly with the specified arguments. If `args` is not provided, the command will be executed through the system shell (cmd on Windows, sh on Unix), allowing for shell features like pipes and redirection.

### Application Operations

#### Open Application

**POST** `/api/app/open`

**Request:**
```json
{
  "path": "C:\\Program Files\\Notepad++\\notepad++.exe",
  "args": ["C:\\Users\\username\\Documents\\file.txt"]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Application launched successfully",
  "process_id": 1234
}
```

#### Shutdown Server

**POST** `/api/app/shutdown`

**Response:**
```json
{
  "success": true,
  "message": "Server shutting down gracefully"
}
```

## 📚 Usage Examples

### JavaScript Client

```javascript
// JavaScript client example
class ExexClient {
    constructor(baseUrl = 'http://127.0.0.1:8080') {
        this.baseUrl = baseUrl;
    }

    async makeRequest(endpoint, data) {
        try {
            const response = await fetch(`${this.baseUrl}${endpoint}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            });
            return await response.json();
        } catch (error) {
            console.error('Request failed:', error);
            return { success: false, error: error.message };
        }
    }

    // File operations
    async readFile(path) {
        return await this.makeRequest('/api/file/read', { path });
    }

    async writeFile(path, content, append = false) {
        return await this.makeRequest('/api/file/write', { path, content, append });
    }

    async deleteFile(path) {
        return await this.makeRequest('/api/file/delete', { path });
    }

    async scanDirectory(path, recursive = true, includeHidden = false) {
        return await this.makeRequest('/api/file/scan', {
            path,
            recursive,
            include_hidden: includeHidden
        });
    }

    // Command execution
    async executeCommand(command, args = null, workingDirectory = null) {
        const payload = {
            command,
            cwd: workingDirectory
        };
        
        // Add args if provided
        if (args && args.length > 0) {
            payload.args = args;
        }
        
        return await this.makeRequest('/api/exec', payload);
    }

    // Application operations
    async openApplication(path, args = []) {
        return await this.makeRequest('/api/app/open', { path, args });
    }

    async shutdown() {
        return await this.makeRequest('/api/app/shutdown', {});
    }
}

// Usage examples
const client = new ExexClient();

// Read a file
client.readFile('C:\\Users\\username\\Documents\\file.txt')
    .then(result => console.log('File content:', result.content));

// Write to a file
client.writeFile('C:\\Users\\username\\Documents\\output.txt', 'Hello, World!')
    .then(result => console.log('Write result:', result));

// Execute a command (using args array - recommended)
client.executeCommand('git', ['status', '--porcelain'], 'C:\\Users\\username\\MyProject')
    .then(result => console.log('Git status:', result.stdout));

// Execute a command (using single command string - backward compatible)
client.executeCommand('echo "Hello from command line"')
    .then(result => console.log('Command output:', result.stdout));

// Scan directory
client.scanDirectory('C:\\Users\\username\\Documents')
    .then(result => {
        console.log('Files:', result.files);
        console.log('Directories:', result.directories);
    });
```

### PowerShell Client

```powershell
# PowerShell client functions
function Invoke-ExexApi {
    param(
        [string]$Endpoint,
        [hashtable]$Data,
        [string]$BaseUrl = "http://127.0.0.1:8080"
    )
    
    try {
        $json = $Data | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" -Method POST -Body $json -ContentType "application/json"
        return $response
    }
    catch {
        Write-Error "API request failed: $_"
        return $null
    }
}

# File operations
function Read-ExexFile {
    param([string]$Path)
    return Invoke-ExexApi -Endpoint "/api/file/read" -Data @{ path = $Path }
}

function Write-ExexFile {
    param([string]$Path, [string]$Content, [bool]$Append = $false)
    return Invoke-ExexApi -Endpoint "/api/file/write" -Data @{ 
        path = $Path
        content = $Content
        append = $Append
    }
}

function Remove-ExexFile {
    param([string]$Path)
    return Invoke-ExexApi -Endpoint "/api/file/delete" -Data @{ path = $Path }
}

function Get-ExexDirectoryContents {
    param([string]$Path, [bool]$Recursive = $true, [bool]$IncludeHidden = $false)
    return Invoke-ExexApi -Endpoint "/api/file/scan" -Data @{
        path = $Path
        recursive = $Recursive
        include_hidden = $IncludeHidden
    }
}

# Command execution
function Invoke-ExexCommand {
    param(
        [string]$Command, 
        [string[]]$Args = $null, 
        [string]$WorkingDirectory = $null
    )
    
    $data = @{
        command = $Command
        cwd = $WorkingDirectory
    }
    
    # Add args if provided
    if ($Args -and $Args.Count -gt 0) {
        $data.args = $Args
    }
    
    return Invoke-ExexApi -Endpoint "/api/exec" -Data $data
}

# Application operations
function Start-ExexApplication {
    param([string]$Path, [string[]]$Args = @())
    return Invoke-ExexApi -Endpoint "/api/app/open" -Data @{
        path = $Path
        args = $Args
    }
}

# Usage examples
# Read file
$fileContent = Read-ExexFile -Path "C:\Users\username\Documents\file.txt"
Write-Host "File content: $($fileContent.content)"

# Write file
$writeResult = Write-ExexFile -Path "C:\Users\username\Documents\output.txt" -Content "Hello from PowerShell!"
Write-Host "Write successful: $($writeResult.success)"

# Execute command (using args array - recommended)
$gitResult = Invoke-ExexCommand -Command "git" -Args @("status", "--porcelain") -WorkingDirectory "C:\Users\username\MyProject"
Write-Host "Git status: $($gitResult.stdout)"

# Execute command (using single command string - backward compatible)
$cmdResult = Invoke-ExexCommand -Command "echo Hello World"
Write-Host "Command output: $($cmdResult.stdout)"

# Scan directory
$scanResult = Get-ExexDirectoryContents -Path "C:\Users\username\Documents"
Write-Host "Found $($scanResult.files.Count) files and $($scanResult.directories.Count) directories"
```

### cURL Examples

```bash
# Health check
curl -X GET http://127.0.0.1:8080/health

# Read file
curl -X POST http://127.0.0.1:8080/api/file/read \
  -H "Content-Type: application/json" \
  -d '{"path": "C:\\Users\\username\\Documents\\file.txt"}'

# Write file
curl -X POST http://127.0.0.1:8080/api/file/write \
  -H "Content-Type: application/json" \
  -d '{"path": "C:\\Users\\username\\Documents\\output.txt", "content": "Hello from cURL!", "append": false}'

# Execute command (using args array - recommended)
curl -X POST http://127.0.0.1:8080/api/exec \
  -H "Content-Type: application/json" \
  -d '{"command": "git", "args": ["status", "--porcelain"], "cwd": "C:\\Users\\username\\MyProject"}'

# Execute command (using single command string - backward compatible)
curl -X POST http://127.0.0.1:8080/api/exec \
  -H "Content-Type: application/json" \
  -d '{"command": "echo Hello World"}'

# Scan directory
curl -X POST http://127.0.0.1:8080/api/file/scan \
  -H "Content-Type: application/json" \
  -d '{"path": "C:\\Users\\username\\Documents", "recursive": true, "include_hidden": false}'

# Open application
curl -X POST http://127.0.0.1:8080/api/app/open \
  -H "Content-Type: application/json" \
  -d '{"path": "C:\\Windows\\notepad.exe", "args": ["C:\\Users\\username\\Documents\\file.txt"]}'
```

## 🔐 Security Features

### Path Validation

- **Canonicalization**: All paths are resolved to absolute paths
- **Traversal Prevention**: Directory traversal attacks (`../`, `..\\`) are blocked
- **Symlink Protection**: Symbolic links are resolved safely

### Error Handling

- **Non-Terminating**: Server never crashes on errors
- **Structured Responses**: All errors return JSON with error details
- **Security Logging**: Path access violations are logged
- **Graceful Degradation**: Failed operations don't affect other requests

### CORS Configuration

- **Cross-Origin Support**: Configured for frontend integration
- **Method Restrictions**: Only necessary HTTP methods allowed
- **Header Validation**: Content-Type and other headers validated

## 🧪 Testing

### Test Structure

- **Unit Tests**: Test individual modules and functions
- **Integration Tests**: Test API endpoints with running server
- **PowerShell Test Suite**: Comprehensive API validation
- **Test Data**: Sample files for testing operations

### Running Tests

```bash
# Run all unit tests
cargo test --lib

# Run integration tests
cargo test --test integration

# Run PowerShell test suite
.\tests\console-test-suite.ps1

# Run all tests using test runner
.\run-tests.ps1
```

### Test Coverage

- ✅ Configuration loading and validation
- ✅ Security model enforcement
- ✅ All file operations (read/write/create/delete/rename/scan)
- ✅ Directory operations (create/delete/rename)
- ✅ Command execution with various scenarios
- ✅ Application launching
- ✅ Error handling and edge cases
- ✅ Cross-platform path handling

## 📦 Installation & Setup

### Prerequisites

- **Rust**: Install from [rustup.rs](https://rustup.rs/)
- **Git**: For cloning the repository

### Build & Run

1. **Clone and build:**

   ```bash
   git clone https://github.com/muhammad-fiaz/EXEX.git
   cd EXEX
   cargo build --release
   ```

2. **Run the server:**

   ```bash
   cargo run
   ```

3. **Test functionality:**

   ```bash
   .\run-tests.ps1
   ```

The server will start on `http://127.0.0.1:8080` and automatically create its configuration file.

## 🔧 Advanced Features

### Batch Operations

The API supports efficient batch operations for multiple files:

```javascript
// Batch file reading
const client = new ExexClient();
const files = [
    'C:\\Users\\username\\Documents\\file1.txt',
    'C:\\Users\\username\\Documents\\file2.txt',
    'C:\\Users\\username\\Documents\\file3.txt'
];

const results = await Promise.all(
    files.map(file => client.readFile(file))
);
```

### Performance Optimizations

- **Async Operations**: All I/O operations are non-blocking
- **Streaming**: Large files are handled with streaming for memory efficiency
- **Connection Pooling**: HTTP connections are reused for better performance
- **Caching**: Configuration is cached to avoid repeated file reads

### Monitoring & Logging

EXEX provides comprehensive logging for monitoring:

```bash
# Server startup logs
[2024-01-01T12:00:00Z] INFO  Starting EXEX server on 127.0.0.1:8080
[2024-01-01T12:00:00Z] INFO  Config loaded from: C:\Users\username\AppData\Local\EXEX\exex.config.json
[2024-01-01T12:00:00Z] INFO  Allowed paths: ["C:\Users\username\Documents"]
[2024-01-01T12:00:00Z] INFO  Disallowed paths: ["C:\Windows", "C:\Program Files"]

# Operation logs
[2024-01-01T12:01:00Z] INFO  File read: C:\Users\username\Documents\file.txt (1024 bytes)
[2024-01-01T12:01:05Z] WARN  Security violation: Attempted access to C:\Windows\System32\file.dll
[2024-01-01T12:01:10Z] INFO  Command executed: echo "Hello World" (exit code: 0)
```

### Extension Points

EXEX is designed for extensibility:

- **Custom Handlers**: Add new API endpoints in `src/handlers/`
- **Security Policies**: Extend security rules in `src/security/`
- **Configuration**: Add new config options in `src/models/`
- **Middleware**: Add request/response middleware in `src/main.rs`

## 🎛️ Configuration Advanced Options

### Environment Variable Override

Configuration can be overridden with environment variables:

```bash
# Override server settings
set EXEX_HOST=0.0.0.0
set EXEX_PORT=9090

# Override security settings
set EXEX_ALLOWED_PATHS=C:\Users\username\Documents;C:\Users\username\Downloads
set EXEX_DISALLOWED_PATHS=C:\Windows;C:\Program Files

# Run with overrides
cargo run
```

### Runtime Configuration Updates

Configuration can be updated at runtime through API endpoints:

```javascript
// Update allowed paths without restart
await client.makeRequest('/api/config/update', {
    security: {
        allowed_paths: [
            'C:\\Users\\username\\Documents',
            'C:\\Users\\username\\Projects'
        ]
    }
});
```

## 🔍 Troubleshooting

### Common Issues

**1. Server Won't Start**
```bash
# Check if port is already in use
netstat -an | findstr :8080

# Try different port
set EXEX_PORT=8081
cargo run
```

**2. Security Violations**
```bash
# Check current security settings
curl -X GET http://127.0.0.1:8080/api/config

# Verify path canonicalization
curl -X POST http://127.0.0.1:8080/api/debug/canonicalize \
  -H "Content-Type: application/json" \
  -d '{"path": "C:\\Users\\username\\..\\..\\Windows"}'
```

**3. Command Execution Fails**
```bash
# Check working directory permissions
# Verify command exists in PATH
# Test with absolute path to executable
```

### Debug Mode

Enable debug logging for detailed troubleshooting:

```bash
# Set debug environment variable
set RUST_LOG=debug
cargo run

# Debug specific modules
set RUST_LOG=exex::security=debug,exex::handlers=debug
cargo run
```

### Performance Tuning

For high-throughput scenarios:

```toml
# Add to Cargo.toml for release builds
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = 'abort'
```

## 📊 Metrics & Analytics

### Built-in Metrics

EXEX tracks operational metrics:

```javascript
// Get server metrics
const metrics = await client.makeRequest('/api/metrics', {});
console.log(metrics);
/*
{
  "uptime_seconds": 3600,
  "requests_total": 1500,
  "requests_per_second": 0.42,
  "files_read": 450,
  "files_written": 200,
  "commands_executed": 50,
  "security_violations": 5,
  "memory_usage_mb": 12.5
}
*/
```

### Health Monitoring

Comprehensive health checks for system monitoring:

```javascript
// Detailed health check
const health = await client.makeRequest('/api/health/detailed', {});
/*
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": "01:00:00",
  "system": {
    "cpu_usage": 2.5,
    "memory_usage": 12.5,
    "disk_usage": 45.2
  },
  "config": {
    "loaded": true,
    "last_modified": "2024-01-01T12:00:00Z"
  },
  "security": {
    "allowed_paths_count": 2,
    "disallowed_paths_count": 3
  }
}
*/
```

## 🚀 Production Deployment

### Service Installation (Windows)

```powershell
# Install as Windows service
sc create "EXEX Local Daemon" binPath="C:\path\to\exex.exe" start=auto
sc description "EXEX Local Daemon" "Local file and command execution API server"
sc start "EXEX Local Daemon"
```

### Reverse Proxy Setup (nginx)

```nginx
server {
    listen 80;
    server_name localhost;
    
    location /exex/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Docker Deployment

```dockerfile
FROM rust:1.70 as builder
WORKDIR /usr/src/exex
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/exex/target/release/exex /usr/local/bin/exex
EXPOSE 8080
CMD ["exex"]
```

## 🔐 Security Best Practices

### Production Security

1. **Network Isolation**: Run on loopback interface only
2. **Path Restrictions**: Use minimal allowed_paths list
3. **Command Filtering**: Restrict executable commands
4. **Audit Logging**: Enable comprehensive logging
5. **Regular Updates**: Keep dependencies updated

### Security Checklist

- [ ] Configure minimal allowed_paths
- [ ] Review all disallowed_paths
- [ ] Enable audit logging
- [ ] Restrict network access
- [ ] Regular security updates
- [ ] Monitor for violations
- [ ] Test security policies

### Secure Configuration Example

```json
{
  "version": "1.0",
  "server": {
    "host": "127.0.0.1",
    "port": 8080
  },
  "security": {
    "allowed_paths": [
      "C:\\Users\\username\\Documents\\Projects",
      "C:\\Users\\username\\Downloads\\Safe"
    ],
    "disallowed_paths": [],
    "command_whitelist": [
      "npm",
      "node",
      "git",
      "code"
    ],
    "command_blacklist": [
      "format",
      "del",
      "rmdir"
    ],
    "max_file_size_mb": 100
  },
  "logging": {
    "level": "info",
    "audit_file": "C:\\Users\\username\\AppData\\Local\\EXEX\\audit.log"
  }
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions to EXEX! Please follow these guidelines:

### Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:

   ```bash
   git clone https://github.com/your-username/EXEX.git
   cd EXEX
   ```

3. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

### Development Setup

1. **Install Rust** (if not already installed):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Build the project**:

   ```bash
   cargo build
   ```

3. **Run tests**:

   ```bash
   cargo test
   ```

4. **Run the test suite**:

   ```powershell
   # PowerShell
   .\tests\console-test-suite.ps1
   ```

### Code Standards

- **Follow Rust conventions**: Use `rustfmt` and `clippy`

  ```bash
  cargo fmt
  cargo clippy
  ```

- **Write tests**: All new features should include unit tests and integration tests
- **Document your code**: Use doc comments for public APIs
- **Security first**: Always consider security implications of changes

### What to Contribute

- **Bug fixes**: Fix issues and include tests
- **New features**: Add new file operations, security enhancements, or platform support
- **Documentation**: Improve README, code comments, or API documentation
- **Tests**: Add test coverage for existing functionality
- **Performance**: Optimize existing operations

### Submitting Changes

1. **Ensure all tests pass**:

   ```bash
   cargo test
   cargo clippy
   cargo fmt --check
   ```

2. **Run the PowerShell test suite**:

   ```powershell
   .\tests\console-test-suite.ps1
   ```

3. **Commit your changes**:

   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

   Use conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `test:` for tests
   - `refactor:` for code refactoring
   - `security:` for security improvements

4. **Push to your fork**:

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request** on GitHub with:
   - Clear description of changes
   - Reference to any related issues
   - Test results and evidence

### Security Considerations

- **Never commit sensitive data** (API keys, passwords, personal paths)
- **Test security features** thoroughly, especially path validation and command filtering
- **Report security vulnerabilities** privately to maintainers before public disclosure
- **Follow secure coding practices** for file operations and command execution

### Code Review Process

1. All submissions require review from maintainers
2. Address feedback and update your PR
3. Ensure CI/CD checks pass
4. Maintainers will merge approved PRs

### Questions or Help?

- **Open an issue** for bugs or feature requests
- **Start a discussion** for questions about usage or architecture
- **Check existing issues** before creating new ones

Thank you for contributing to EXEX! 🚀
