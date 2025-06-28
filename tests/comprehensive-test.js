#!/usr/bin/env node

// Comprehensive API Test Suite for EXEX
const BASE_URL = 'http://127.0.0.1:8080';
const fs = require('fs').promises;
const path = require('path');

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

async function runComprehensiveTests() {
    console.log('🧪 EXEX Comprehensive API Test Suite\n');

    const testResults = {
        passed: 0,
        failed: 0,
        tests: []
    };

    // Test 1: Health Check
    console.log('1️⃣ Testing Health Check');
    const healthResult = await makeRequest('/health');
    if (healthResult.success && healthResult.data.status === 'healthy') {
        testResults.passed++;
        testResults.tests.push({ name: 'Health Check', status: 'PASS' });
        console.log('✅ Health check passed\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Health Check', status: 'FAIL' });
        console.log('❌ Health check failed\n');
    }

    // Test 2: Read test data file
    console.log('2️⃣ Testing Read Test Data File');
    const testDataPath = path.join(process.cwd(), 'tests', 'test_data', 'test_data.txt');
    const readTestDataResult = await makeRequest('/api/read', {
        path: testDataPath
    });
    if (readTestDataResult.success && readTestDataResult.data.success && 
        readTestDataResult.data.content.includes('EXEX Test Data File')) {
        testResults.passed++;
        testResults.tests.push({ name: 'Read Test Data', status: 'PASS' });
        console.log('✅ Test data file read successfully\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Read Test Data', status: 'FAIL' });
        console.log('❌ Failed to read test data file\n');
    }

    // Test 3: Execute Safe Command
    console.log('3️⃣ Testing Safe Command Execution');
    const execResult = await makeRequest('/api/exec', {
        command: 'echo Testing EXEX Command Execution',
        cwd: process.env.USERPROFILE || 'C:\\Users'
    });
    if (execResult.success && execResult.data.success && 
        execResult.data.stdout.includes('Testing EXEX Command Execution')) {
        testResults.passed++;
        testResults.tests.push({ name: 'Safe Command Execution', status: 'PASS' });
        console.log('✅ Safe command executed successfully\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Safe Command Execution', status: 'FAIL' });
        console.log('❌ Safe command execution failed\n');
    }

    // Test 4: Write and Read File Operations
    console.log('4️⃣ Testing File Write/Read Operations');
    const testFilePath = path.join(process.env.USERPROFILE || 'C:\\Users', 'Desktop', 'exex-comprehensive-test.txt');
    const testContent = `EXEX Comprehensive Test
Created: ${new Date().toISOString()}
Content: Multi-line test data
Special chars: áéíóú ñ !@#$%
Numbers: 123456789
End of test`;

    const writeResult = await makeRequest('/api/write', {
        path: testFilePath,
        content: testContent
    });

    if (writeResult.success && writeResult.data.success) {
        const readResult = await makeRequest('/api/read', {
            path: testFilePath
        });
        
        if (readResult.success && readResult.data.success && 
            readResult.data.content === testContent) {
            testResults.passed++;
            testResults.tests.push({ name: 'File Write/Read Operations', status: 'PASS' });
            console.log('✅ File write/read operations successful\n');
        } else {
            testResults.failed++;
            testResults.tests.push({ name: 'File Write/Read Operations', status: 'FAIL' });
            console.log('❌ File read operation failed\n');
        }
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'File Write/Read Operations', status: 'FAIL' });
        console.log('❌ File write operation failed\n');
    }

    // Test 5: Security - Restricted Path Access
    console.log('5️⃣ Testing Security (Restricted Path Access)');
    const securityResult = await makeRequest('/api/read', {
        path: 'C:\\Windows\\System32\\kernel32.dll'
    });
    if (securityResult.status === 403 || 
        (securityResult.data && securityResult.data.error && 
         securityResult.data.error.includes('Access denied'))) {
        testResults.passed++;
        testResults.tests.push({ name: 'Security - Restricted Access', status: 'PASS' });
        console.log('✅ Security restriction working correctly\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Security - Restricted Access', status: 'FAIL' });
        console.log('❌ Security restriction failed\n');
    }

    // Test 6: Directory Listing
    console.log('6️⃣ Testing Directory Listing');
    const dirResult = await makeRequest('/api/exec', {
        command: 'dir',
        cwd: process.env.USERPROFILE || 'C:\\Users'
    });
    if (dirResult.success && dirResult.data.success && dirResult.data.stdout.length > 0) {
        testResults.passed++;
        testResults.tests.push({ name: 'Directory Listing', status: 'PASS' });
        console.log('✅ Directory listing successful\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Directory Listing', status: 'FAIL' });
        console.log('❌ Directory listing failed\n');
    }

    // Test 7: Invalid Command Handling
    console.log('7️⃣ Testing Invalid Command Handling');
    const invalidCmdResult = await makeRequest('/api/exec', {
        command: 'nonexistentcommand12345xyz',
        cwd: process.env.USERPROFILE || 'C:\\Users'
    });
    if (invalidCmdResult.success && !invalidCmdResult.data.success) {
        testResults.passed++;
        testResults.tests.push({ name: 'Invalid Command Handling', status: 'PASS' });
        console.log('✅ Invalid command handled correctly\n');
    } else {
        testResults.failed++;
        testResults.tests.push({ name: 'Invalid Command Handling', status: 'FAIL' });
        console.log('❌ Invalid command handling failed\n');
    }

    // Test Summary
    console.log('📊 Test Summary');
    console.log('==============');
    console.log(`Total Tests: ${testResults.passed + testResults.failed}`);
    console.log(`Passed: ${testResults.passed} ✅`);
    console.log(`Failed: ${testResults.failed} ❌`);
    console.log(`Success Rate: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);
    
    console.log('\n📋 Detailed Results:');
    testResults.tests.forEach(test => {
        const status = test.status === 'PASS' ? '✅' : '❌';
        console.log(`  ${status} ${test.name}`);
    });

    if (testResults.failed === 0) {
        console.log('\n🎉 All tests passed! EXEX is working correctly.');
    } else {
        console.log(`\n⚠️  ${testResults.failed} test(s) failed. Please check the EXEX server.`);
    }
}

// Check if we're running in Node.js environment
if (typeof fetch === 'undefined') {
    console.log('❌ This test requires Node.js 18+ with built-in fetch support.');
    console.log('Run with: node comprehensive-test.js');
    process.exit(1);
}

runComprehensiveTests().catch(console.error);
