#!/usr/bin/env node

/**
 * EXEX Client Example
 * Demonstrates how to use the EXEX API for various operations
 */

const BASE_URL = 'http://127.0.0.1:8080';

class ExexClient {
    constructor(baseUrl = BASE_URL) {
        this.baseUrl = baseUrl;
    }

    async makeRequest(endpoint, data = null) {
        const url = `${this.baseUrl}${endpoint}`;
        const options = {
            method: data ? 'POST' : 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }

        const response = await fetch(url, options);
        return await response.json();
    }

    async healthCheck() {
        return await this.makeRequest('/health');
    }

    async executeCommand(command, workingDirectory = null) {
        return await this.makeRequest('/api/exec', {
            command,
            cwd: workingDirectory
        });
    }

    async readFile(filePath) {
        return await this.makeRequest('/api/read', {
            path: filePath
        });
    }

    async writeFile(filePath, content) {
        return await this.makeRequest('/api/write', {
            path: filePath,
            content: content
        });
    }
}

async function demonstrateExexUsage() {
    console.log('🚀 EXEX Client Usage Demonstration\n');

    const client = new ExexClient();

    try {
        // 1. Health Check
        console.log('1️⃣ Checking EXEX Health...');
        const health = await client.healthCheck();
        console.log('Health Status:', health);
        console.log('');

        // 2. Execute a simple command
        console.log('2️⃣ Executing a simple command...');
        const echoResult = await client.executeCommand('echo Hello from EXEX Client!');
        console.log('Command Result:', echoResult);
        console.log('');

        // 3. Get system information
        console.log('3️⃣ Getting system information...');
        const systemInfo = await client.executeCommand('systeminfo | findstr /C:"OS Name" /C:"Total Physical Memory"');
        console.log('System Info:', systemInfo);
        console.log('');

        // 4. List files in user directory
        console.log('4️⃣ Listing files in user directory...');
        const dirList = await client.executeCommand('dir', process.env.USERPROFILE);
        console.log('Directory Listing (first 500 chars):', dirList.stdout?.substring(0, 500) + '...');
        console.log('');

        // 5. Create and read a file
        console.log('5️⃣ Creating and reading a file...');
        const testFilePath = `${process.env.USERPROFILE}\\Desktop\\exex-client-demo.txt`;
        const fileContent = `EXEX Client Demo File
Created: ${new Date().toISOString()}
This file was created using the EXEX client library.

Capabilities demonstrated:
✅ Command execution
✅ File creation
✅ File reading
✅ System integration

EXEX makes it easy to build desktop applications with web technologies!`;

        const writeResult = await client.writeFile(testFilePath, fileContent);
        console.log('Write Result:', writeResult);

        if (writeResult.success) {
            const readResult = await client.readFile(testFilePath);
            console.log('Read Result Success:', readResult.success);
            console.log('File Content Preview:', readResult.content?.substring(0, 200) + '...');
        }
        console.log('');

        // 6. Try to access a restricted path (should fail)
        console.log('6️⃣ Testing security (accessing restricted path)...');
        const securityTest = await client.readFile('C:\\Windows\\System32\\kernel32.dll');
        console.log('Security Test Result:', securityTest);
        console.log('');

        console.log('✅ EXEX Client demonstration completed successfully!');
        console.log('💡 You can now build powerful desktop applications using web technologies and EXEX!');

    } catch (error) {
        console.error('❌ Error during demonstration:', error.message);
        console.log('💡 Make sure EXEX server is running on http://127.0.0.1:8080');
    }
}

// Example of using EXEX for a practical task
async function practicalExample() {
    console.log('\n🛠️ Practical Example: Project Setup Automation\n');
    
    const client = new ExexClient();
    const projectPath = `${process.env.USERPROFILE}\\Desktop\\my-new-project`;

    try {
        // Create project directory
        console.log('Creating project directory...');
        await client.executeCommand(`mkdir "${projectPath}"`, process.env.USERPROFILE + '\\Desktop');

        // Create package.json
        console.log('Creating package.json...');
        const packageJson = {
            name: 'my-new-project',
            version: '1.0.0',
            description: 'A project created with EXEX',
            main: 'index.js',
            scripts: {
                start: 'node index.js'
            }
        };
        await client.writeFile(`${projectPath}\\package.json`, JSON.stringify(packageJson, null, 2));

        // Create main file
        console.log('Creating index.js...');
        const indexJs = `console.log('Hello from my EXEX-created project!');
console.log('Project created at: ${new Date().toISOString()}');`;
        await client.writeFile(`${projectPath}\\index.js`, indexJs);

        // Create README
        console.log('Creating README.md...');
        const readme = `# My New Project

This project was created automatically using EXEX!

## Getting Started

\`\`\`bash
npm start
\`\`\`

Created on: ${new Date().toISOString()}
`;
        await client.writeFile(`${projectPath}\\README.md`, readme);

        console.log('✅ Project setup completed!');
        console.log(`📁 Project created at: ${projectPath}`);

    } catch (error) {
        console.error('❌ Error in practical example:', error.message);
    }
}

// Check environment and run examples
if (typeof fetch === 'undefined') {
    console.log('❌ This example requires Node.js 18+ with built-in fetch support.');
    process.exit(1);
}

// Run demonstrations
demonstrateExexUsage()
    .then(() => practicalExample())
    .catch(console.error);
