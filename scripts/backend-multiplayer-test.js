#!/usr/bin/env node

/**
 * Backend Multi-player Testing Script
 * Tests the backend Game Center authentication and multiplayer functionality
 */

const WebSocket = require('ws');
const https = require('https');

const BACKEND_URL = 'https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/dev';
const WS_URL = 'wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev';

// Mock Game Center tokens for testing
const mockGameCenterTokens = {
    player1: Buffer.from(JSON.stringify({
        playerId: 'G:1234567890',
        signature: 'mock-signature-1',
        salt: 'mock-salt-1',
        timestamp: Date.now(),
        bundleId: 'com.botanybattle.app'
    })).toString('base64'),
    player2: Buffer.from(JSON.stringify({
        playerId: 'G:1234567891',
        signature: 'mock-signature-2',
        salt: 'mock-salt-2',
        timestamp: Date.now(),
        bundleId: 'com.botanybattle.app'
    })).toString('base64')
};

class BackendTester {
    constructor() {
        this.testResults = {
            passed: 0,
            failed: 0,
            tests: []
        };
    }

    log(message, type = 'info') {
        const timestamp = new Date().toISOString();
        const prefix = type === 'error' ? '❌' : type === 'success' ? '✅' : '📋';
        console.log(`${prefix} [${timestamp}] ${message}`);
    }

    async makeRequest(endpoint, method = 'GET', data = null, headers = {}) {
        return new Promise((resolve, reject) => {
            const url = new URL(endpoint, BACKEND_URL);
            const options = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    ...headers
                }
            };

            const req = https.request(url, options, (res) => {
                let body = '';
                res.on('data', (chunk) => body += chunk);
                res.on('end', () => {
                    try {
                        const responseData = body ? JSON.parse(body) : {};
                        resolve({ status: res.statusCode, data: responseData, headers: res.headers });
                    } catch (error) {
                        resolve({ status: res.statusCode, data: body, headers: res.headers });
                    }
                });
            });

            req.on('error', reject);
            
            if (data) {
                req.write(JSON.stringify(data));
            }
            
            req.end();
        });
    }

    async testGameCenterAuth() {
        this.log('Testing Game Center Authentication...');
        
        try {
            // Test without token (should fail)
            const responseNoToken = await this.makeRequest('/auth/gamecenter', 'POST', {});
            if (responseNoToken.status === 403) {
                this.recordTest('Game Center Auth - No Token', true, 'Correctly rejected request without token');
            } else {
                this.recordTest('Game Center Auth - No Token', false, `Expected 403, got ${responseNoToken.status}`);
            }

            // Test with mock token
            const responseWithToken = await this.makeRequest('/auth/gamecenter', 'POST', {
                token: mockGameCenterTokens.player1
            });
            
            if (responseWithToken.status === 200 || responseWithToken.status === 400) {
                this.recordTest('Game Center Auth - With Token', true, 'Backend processed Game Center token');
            } else {
                this.recordTest('Game Center Auth - With Token', false, `Unexpected status: ${responseWithToken.status}`);
            }

        } catch (error) {
            this.recordTest('Game Center Auth', false, `Error: ${error.message}`);
        }
    }

    async testPlantEndpoint() {
        this.log('Testing Plant Endpoint...');
        
        try {
            const response = await this.makeRequest('/plant', 'GET');
            
            if (response.status === 200) {
                this.recordTest('Plant Endpoint', true, 'Plant endpoint responding correctly');
            } else {
                this.recordTest('Plant Endpoint', false, `Expected 200, got ${response.status}`);
            }
        } catch (error) {
            this.recordTest('Plant Endpoint', false, `Error: ${error.message}`);
        }
    }

    async testWebSocketConnection() {
        this.log('Testing WebSocket Connection...');
        
        return new Promise((resolve) => {
            try {
                const ws = new WebSocket(WS_URL);
                let connected = false;
                
                const timeout = setTimeout(() => {
                    if (!connected) {
                        this.recordTest('WebSocket Connection', false, 'Connection timeout');
                        ws.terminate();
                        resolve();
                    }
                }, 5000);

                ws.on('open', () => {
                    connected = true;
                    clearTimeout(timeout);
                    this.recordTest('WebSocket Connection', true, 'Successfully connected to WebSocket');
                    
                    // Test sending a message
                    ws.send(JSON.stringify({ action: 'ping', playerId: 'test' }));
                    
                    // Close after brief test
                    setTimeout(() => {
                        ws.close();
                        resolve();
                    }, 1000);
                });

                ws.on('error', (error) => {
                    clearTimeout(timeout);
                    this.recordTest('WebSocket Connection', false, `WebSocket error: ${error.message}`);
                    resolve();
                });

                ws.on('message', (data) => {
                    this.log(`WebSocket message received: ${data}`);
                });

            } catch (error) {
                this.recordTest('WebSocket Connection', false, `Error: ${error.message}`);
                resolve();
            }
        });
    }

    async testGameFlow() {
        this.log('Testing Game Flow...');
        
        try {
            // Test creating a game
            const gameResponse = await this.makeRequest('/game', 'POST', {
                difficulty: 'medium'
            });
            
            if (gameResponse.status === 200 || gameResponse.status === 201) {
                this.recordTest('Game Creation', true, 'Game creation endpoint responding');
            } else {
                this.recordTest('Game Creation', false, `Expected 200/201, got ${gameResponse.status}`);
            }

        } catch (error) {
            this.recordTest('Game Flow', false, `Error: ${error.message}`);
        }
    }

    async simulateMultiPlayerScenario() {
        this.log('Simulating Multi-player Scenario...');
        
        try {
            // Simulate two players connecting
            const ws1 = new WebSocket(WS_URL);
            const ws2 = new WebSocket(WS_URL);
            
            let player1Connected = false;
            let player2Connected = false;
            
            const checkBothConnected = () => {
                if (player1Connected && player2Connected) {
                    this.recordTest('Multi-player Simulation', true, 'Both players can connect simultaneously');
                    setTimeout(() => {
                        ws1.close();
                        ws2.close();
                    }, 1000);
                }
            };

            ws1.on('open', () => {
                player1Connected = true;
                this.log('Player 1 connected');
                ws1.send(JSON.stringify({ 
                    action: 'join_game', 
                    playerId: 'G:1234567890',
                    token: mockGameCenterTokens.player1
                }));
                checkBothConnected();
            });

            ws2.on('open', () => {
                player2Connected = true;
                this.log('Player 2 connected');
                ws2.send(JSON.stringify({ 
                    action: 'join_game', 
                    playerId: 'G:1234567891',
                    token: mockGameCenterTokens.player2
                }));
                checkBothConnected();
            });

            // Wait for connections
            await new Promise(resolve => setTimeout(resolve, 3000));

        } catch (error) {
            this.recordTest('Multi-player Simulation', false, `Error: ${error.message}`);
        }
    }

    recordTest(name, passed, details) {
        this.testResults.tests.push({ name, passed, details });
        if (passed) {
            this.testResults.passed++;
            this.log(`${name}: PASSED - ${details}`, 'success');
        } else {
            this.testResults.failed++;
            this.log(`${name}: FAILED - ${details}`, 'error');
        }
    }

    async runAllTests() {
        this.log('🌿 Starting Backend Multi-player Tests');
        this.log('=====================================');
        
        await this.testPlantEndpoint();
        await this.testGameCenterAuth();
        await this.testWebSocketConnection();
        await this.testGameFlow();
        await this.simulateMultiPlayerScenario();
        
        this.printSummary();
    }

    printSummary() {
        this.log('=====================================');
        this.log('📊 Test Summary');
        this.log(`Total Tests: ${this.testResults.passed + this.testResults.failed}`);
        this.log(`Passed: ${this.testResults.passed}`, 'success');
        this.log(`Failed: ${this.testResults.failed}`, this.testResults.failed > 0 ? 'error' : 'success');
        
        if (this.testResults.failed > 0) {
            this.log('');
            this.log('Failed Tests:');
            this.testResults.tests
                .filter(test => !test.passed)
                .forEach(test => {
                    this.log(`  - ${test.name}: ${test.details}`, 'error');
                });
        }

        this.log('');
        this.log('🎯 Next Steps for iOS Multi-player Testing:');
        this.log('1. Fix iOS compilation issues (GameKit API usage)');
        this.log('2. Create Game Center sandbox test accounts');
        this.log('3. Test authentication on physical iOS devices');
        this.log('4. Test real-time matchmaking between devices');
        this.log('5. Verify game state synchronization');
    }
}

// Run tests if this script is executed directly
if (require.main === module) {
    const tester = new BackendTester();
    tester.runAllTests().catch(console.error);
}

module.exports = BackendTester;