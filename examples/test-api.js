#!/usr/bin/env node

const BASE_URL = 'http://127.0.0.1:8080';

async function makeRequest(endpoint, data = null) {
    try {
        const options = {
            method: data ? 'POST' : 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
        };
        
        if (data) {
            options.body = JSON.stringify(data);
        }

        console.log(`🔄 ${options.method} ${BASE_URL}${endpoint}`);
        if (data) {
            console.log(`📤 Request:`, JSON.stringify(data, null, 2));
        }

        const response = await fetch(`${BASE_URL}${endpoint}`, options);
        const result = await response.json();
        
        console.log(`📥 Response (${response.status}):`, JSON.stringify(result, null, 2));
        console.log('---');
        
        return {
            success: response.ok,
            status: response.status,
            data: result
        };
    } catch (error) {
        console.error(`❌ Error:`, error.message);
        return {
            success: false,
            error: error.message
        };
    }
}

async function runTests() {
    console.log('🧪 EXEX API Test Suite\n');

    // Test 1: Health Check
    console.log('1️⃣ Testing Health Check');
    await makeRequest('/health');

    // Test 2: Execute Command
    console.log('2️⃣ Testing Command Execution');
    await makeRequest('/api/exec', {
        command: 'echo Hello from EXEX!',
        cwd: process.env.USERPROFILE || 'C:\\Users'
    });

    // Test 3: Execute Directory Listing
    console.log('3️⃣ Testing Directory Listing');
    await makeRequest('/api/exec', {
        command: 'dir',
        cwd: process.env.USERPROFILE || 'C:\\Users'
    });

    // Test 4: Read File (this will fail if file doesn't exist, which is expected)
    console.log('4️⃣ Testing File Read (may fail if file doesn\'t exist)');
    await makeRequest('/api/read', {
        path: (process.env.USERPROFILE || 'C:\\Users') + '\\Desktop\\test.txt'
    });

    // Test 5: Write File
    console.log('5️⃣ Testing File Write');
    const testFilePath = (process.env.USERPROFILE || 'C:\\Users') + '\\Desktop\\exex-test.txt';
    await makeRequest('/api/write', {
        path: testFilePath,
        content: `EXEX Test File\nCreated at: ${new Date().toISOString()}\nTest successful!`
    });

    // Test 6: Read the file we just wrote
    console.log('6️⃣ Testing Read of Written File');
    await makeRequest('/api/read', {
        path: testFilePath
    });

    // Test 7: Test Security - Try to access restricted path
    console.log('7️⃣ Testing Security (should be denied)');
    await makeRequest('/api/read', {
        path: 'C:\\Windows\\System32\\kernel32.dll'
    });

    console.log('✅ Test suite completed!');
    console.log('\nNote: Some tests may fail if files don\'t exist or permissions are insufficient.');
    console.log('The security test should show "Access denied" - this is expected behavior.');
}

// Check if we're running in Node.js environment
if (typeof fetch === 'undefined') {
    console.log('❌ This test requires Node.js 18+ with built-in fetch support.');
    console.log('Run with: node test-api.js');
    process.exit(1);
}

runTests().catch(console.error);
