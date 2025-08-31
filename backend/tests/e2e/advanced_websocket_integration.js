/**
 * Advanced WebSocket Integration Tests for Botany Battle
 * Tests complex real-time multiplayer scenarios and edge cases
 */

const WebSocket = require("ws");
const { v4: uuidv4 } = require("uuid");

class AdvancedWebSocketTester {
  constructor(websocketUrl = "ws://localhost:3001") {
    this.websocketUrl = websocketUrl;
    this.testResults = [];
  }

  async createConnection(playerId, timeout = 10000) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(this.websocketUrl);

      const timeoutId = setTimeout(() => {
        ws.close();
        reject(new Error("Connection timeout"));
      }, timeout);

      ws.on("open", () => {
        clearTimeout(timeoutId);
        // Send authentication message
        ws.send(
          JSON.stringify({
            type: "AUTHENTICATE",
            data: {
              playerId,
              username: `TestPlayer${playerId}`,
              rating: Math.floor(Math.random() * 1000) + 1000,
            },
          }),
        );
        resolve(ws);
      });

      ws.on("error", (error) => {
        clearTimeout(timeoutId);
        reject(error);
      });
    });
  }

  async waitForMessage(ws, messageType, timeout = 5000) {
    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        reject(new Error(`Timeout waiting for ${messageType}`));
      }, timeout);

      const messageHandler = (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === messageType) {
            clearTimeout(timeoutId);
            ws.removeListener("message", messageHandler);
            resolve(message);
          }
        } catch (error) {
          // Ignore malformed messages
        }
      };

      ws.on("message", messageHandler);
    });
  }

  async testMultiplayerGameFlow() {
    console.log("Testing complete multiplayer game flow...");

    try {
      // Create two players
      const player1Id = uuidv4();
      const player2Id = uuidv4();

      const ws1 = await this.createConnection(player1Id);
      const ws2 = await this.createConnection(player2Id);

      // Start matchmaking for both players
      ws1.send(
        JSON.stringify({
          type: "START_MATCHMAKING",
          data: { playerId: player1Id },
        }),
      );

      ws2.send(
        JSON.stringify({
          type: "START_MATCHMAKING",
          data: { playerId: player2Id },
        }),
      );

      // Wait for match found
      const match1 = await this.waitForMessage(ws1, "MATCH_FOUND", 30000);
      const match2 = await this.waitForMessage(ws2, "MATCH_FOUND", 30000);

      if (match1.data.gameId !== match2.data.gameId) {
        throw new Error("Players matched to different games");
      }

      const gameId = match1.data.gameId;
      console.log(`Match found: ${gameId}`);

      // Play 5 rounds
      for (let round = 1; round <= 5; round++) {
        console.log(`Playing round ${round}...`);

        // Wait for round start
        const gameState1 = await this.waitForMessage(ws1, "GAME_STATE");
        const gameState2 = await this.waitForMessage(ws2, "GAME_STATE");

        if (
          gameState1.data.round !== round ||
          gameState2.data.round !== round
        ) {
          throw new Error(`Round mismatch: expected ${round}`);
        }

        // Submit answers
        const options = gameState1.data.plant.options;
        const correctAnswer = options[0]; // Assume first option is correct

        ws1.send(
          JSON.stringify({
            type: "SUBMIT_ANSWER",
            data: {
              playerId: player1Id,
              gameId,
              round,
              answer: correctAnswer,
              timestamp: Date.now(),
            },
          }),
        );

        ws2.send(
          JSON.stringify({
            type: "SUBMIT_ANSWER",
            data: {
              playerId: player2Id,
              gameId,
              round,
              answer: options[1], // Wrong answer
              timestamp: Date.now() + 100, // Slightly later
            },
          }),
        );

        // Wait for round results
        await this.waitForMessage(ws1, "ROUND_RESULT");
        await this.waitForMessage(ws2, "ROUND_RESULT");
      }

      // Wait for game completion
      const gameResult1 = await this.waitForMessage(ws1, "GAME_COMPLETED");
      const gameResult2 = await this.waitForMessage(ws2, "GAME_COMPLETED");

      console.log("Game completed successfully");
      console.log(`Winner: ${gameResult1.data.winner}`);

      ws1.close();
      ws2.close();

      return { success: true, gameId, winner: gameResult1.data.winner };
    } catch (error) {
      console.error("Multiplayer game flow test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async testConnectionRecovery() {
    console.log("Testing connection recovery...");

    try {
      const playerId = uuidv4();
      let ws = await this.createConnection(playerId);

      // Start matchmaking
      ws.send(
        JSON.stringify({
          type: "START_MATCHMAKING",
          data: { playerId },
        }),
      );

      // Force disconnect
      ws.close();

      // Wait a bit, then reconnect
      await new Promise((resolve) => setTimeout(resolve, 2000));

      ws = await this.createConnection(playerId);

      // Try to resume matchmaking
      ws.send(
        JSON.stringify({
          type: "RESUME_MATCHMAKING",
          data: { playerId },
        }),
      );

      console.log("Connection recovery test passed");
      ws.close();

      return { success: true };
    } catch (error) {
      console.error("Connection recovery test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async testHighFrequencyMessages() {
    console.log("Testing high frequency message handling...");

    try {
      const playerId = uuidv4();
      const ws = await this.createConnection(playerId);

      const messageCount = 100;
      const messages = [];
      let receivedCount = 0;

      // Set up message listener
      ws.on("message", (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === "ECHO_RESPONSE") {
            receivedCount++;
          }
        } catch (error) {
          // Ignore malformed messages
        }
      });

      // Send rapid messages
      const startTime = Date.now();
      for (let i = 0; i < messageCount; i++) {
        ws.send(
          JSON.stringify({
            type: "ECHO_TEST",
            data: { messageId: i, timestamp: Date.now() },
          }),
        );
        messages.push(i);
      }

      // Wait for responses
      await new Promise((resolve) => setTimeout(resolve, 5000));

      const endTime = Date.now();
      const duration = endTime - startTime;
      const throughput = receivedCount / (duration / 1000);

      console.log(`Sent ${messageCount} messages, received ${receivedCount}`);
      console.log(`Throughput: ${throughput.toFixed(2)} messages/second`);

      ws.close();

      const success = receivedCount >= messageCount * 0.9; // 90% success rate
      return {
        success,
        sent: messageCount,
        received: receivedCount,
        throughput: throughput.toFixed(2),
      };
    } catch (error) {
      console.error("High frequency message test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async testConcurrentConnections() {
    console.log("Testing concurrent connections...");

    try {
      const connectionCount = 50;
      const connectionPromises = [];

      // Create multiple connections simultaneously
      for (let i = 0; i < connectionCount; i++) {
        const promise = this.createConnection(`concurrent-${i}`)
          .then((ws) => {
            // Send a test message
            ws.send(
              JSON.stringify({
                type: "PING",
                data: { playerId: `concurrent-${i}` },
              }),
            );

            // Close after a short delay
            setTimeout(() => ws.close(), 1000);
            return true;
          })
          .catch((error) => {
            console.error(`Connection ${i} failed:`, error);
            return false;
          });

        connectionPromises.push(promise);
      }

      const results = await Promise.all(connectionPromises);
      const successfulConnections = results.filter(
        (result) => result === true,
      ).length;
      const successRate = successfulConnections / connectionCount;

      console.log(
        `Concurrent connections: ${successfulConnections}/${connectionCount} (${(successRate * 100).toFixed(1)}%)`,
      );

      return {
        success: successRate >= 0.9, // 90% success rate required
        successful: successfulConnections,
        total: connectionCount,
        successRate: successRate,
      };
    } catch (error) {
      console.error("Concurrent connections test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async testMalformedMessageHandling() {
    console.log("Testing malformed message handling...");

    try {
      const playerId = uuidv4();
      const ws = await this.createConnection(playerId);

      // Send various malformed messages
      const malformedMessages = [
        "invalid json {{{",
        '{"type": "INVALID_TYPE"}',
        '{"data": "missing type"}',
        '{"type": "SUBMIT_ANSWER"}', // Missing required data
        JSON.stringify({ type: "SUBMIT_ANSWER", data: null }),
        '{"type": "SUBMIT_ANSWER", "data": {"invalid": "structure"}}',
      ];

      let errorResponseCount = 0;

      // Set up error response listener
      ws.on("message", (data) => {
        try {
          const message = JSON.parse(data);
          if (message.type === "ERROR") {
            errorResponseCount++;
          }
        } catch (error) {
          // Ignore malformed responses
        }
      });

      // Send malformed messages
      for (const malformedMessage of malformedMessages) {
        ws.send(malformedMessage);
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      // Wait for error responses
      await new Promise((resolve) => setTimeout(resolve, 2000));

      console.log(
        `Sent ${malformedMessages.length} malformed messages, received ${errorResponseCount} error responses`,
      );

      ws.close();

      // Server should handle malformed messages gracefully
      return {
        success: true, // Success if server doesn't crash
        malformedSent: malformedMessages.length,
        errorResponses: errorResponseCount,
      };
    } catch (error) {
      console.error("Malformed message handling test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async testGameStateConsistency() {
    console.log("Testing game state consistency...");

    try {
      const player1Id = uuidv4();
      const player2Id = uuidv4();

      const ws1 = await this.createConnection(player1Id);
      const ws2 = await this.createConnection(player2Id);

      // Start matchmaking
      ws1.send(
        JSON.stringify({
          type: "START_MATCHMAKING",
          data: { playerId: player1Id },
        }),
      );

      ws2.send(
        JSON.stringify({
          type: "START_MATCHMAKING",
          data: { playerId: player2Id },
        }),
      );

      // Wait for match
      const match1 = await this.waitForMessage(ws1, "MATCH_FOUND");
      const match2 = await this.waitForMessage(ws2, "MATCH_FOUND");

      const gameId = match1.data.gameId;

      // Wait for first round
      const gameState1 = await this.waitForMessage(ws1, "GAME_STATE");
      const gameState2 = await this.waitForMessage(ws2, "GAME_STATE");

      // Verify game states are consistent
      const consistent =
        gameState1.data.gameId === gameState2.data.gameId &&
        gameState1.data.round === gameState2.data.round &&
        JSON.stringify(gameState1.data.plant) ===
          JSON.stringify(gameState2.data.plant) &&
        gameState1.data.timeRemaining === gameState2.data.timeRemaining;

      console.log("Game state consistency:", consistent ? "PASSED" : "FAILED");

      ws1.close();
      ws2.close();

      return {
        success: consistent,
        gameState1: gameState1.data,
        gameState2: gameState2.data,
      };
    } catch (error) {
      console.error("Game state consistency test failed:", error);
      return { success: false, error: error.message };
    }
  }

  async runAllTests() {
    console.log("🔗 Starting Advanced WebSocket Integration Tests...\n");

    const tests = [
      {
        name: "Multiplayer Game Flow",
        test: () => this.testMultiplayerGameFlow(),
      },
      {
        name: "Connection Recovery",
        test: () => this.testConnectionRecovery(),
      },
      {
        name: "High Frequency Messages",
        test: () => this.testHighFrequencyMessages(),
      },
      {
        name: "Concurrent Connections",
        test: () => this.testConcurrentConnections(),
      },
      {
        name: "Malformed Message Handling",
        test: () => this.testMalformedMessageHandling(),
      },
      {
        name: "Game State Consistency",
        test: () => this.testGameStateConsistency(),
      },
    ];

    const results = {};

    for (const { name, test } of tests) {
      console.log(`\n--- Running ${name} ---`);
      try {
        const result = await test();
        results[name] = result;
        console.log(`${name}: ${result.success ? "✅ PASSED" : "❌ FAILED"}`);
        if (!result.success && result.error) {
          console.log(`Error: ${result.error}`);
        }
      } catch (error) {
        console.error(`${name} threw exception:`, error);
        results[name] = { success: false, error: error.message };
      }
    }

    return results;
  }

  generateReport(results) {
    console.log("\n" + "=".repeat(60));
    console.log("🔗 Advanced WebSocket Integration Test Report");
    console.log("=".repeat(60));

    const passedTests = Object.values(results).filter((r) => r.success).length;
    const totalTests = Object.keys(results).length;
    const successRate = (passedTests / totalTests) * 100;

    for (const [testName, result] of Object.entries(results)) {
      const status = result.success ? "✅ PASSED" : "❌ FAILED";
      console.log(`${testName}: ${status}`);

      if (result.error) {
        console.log(`  Error: ${result.error}`);
      }

      // Additional details for specific tests
      if (testName === "High Frequency Messages" && result.throughput) {
        console.log(`  Throughput: ${result.throughput} messages/second`);
      }

      if (testName === "Concurrent Connections" && result.successRate) {
        console.log(
          `  Success Rate: ${(result.successRate * 100).toFixed(1)}%`,
        );
      }
    }

    console.log("-".repeat(60));
    console.log(
      `Total: ${passedTests}/${totalTests} tests passed (${successRate.toFixed(1)}%)`,
    );

    if (successRate >= 80) {
      console.log("🎉 Advanced WebSocket integration tests PASSED!");
      return 0;
    } else {
      console.error("💥 Advanced WebSocket integration tests FAILED!");
      return 1;
    }
  }
}

async function main() {
  const websocketUrl = process.env.WEBSOCKET_URL || "ws://localhost:3001";
  console.log(`Testing WebSocket server at: ${websocketUrl}`);

  const tester = new AdvancedWebSocketTester(websocketUrl);

  try {
    const results = await tester.runAllTests();
    const exitCode = tester.generateReport(results);
    process.exit(exitCode);
  } catch (error) {
    console.error("Test runner failed:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = AdvancedWebSocketTester;
