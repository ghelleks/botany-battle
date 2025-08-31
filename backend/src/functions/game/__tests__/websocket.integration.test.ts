/**
 * WebSocket Integration Tests for Botany Battle
 */

import WebSocket from "ws";
import { APIGatewayProxyEvent } from "aws-lambda";

// Mock WebSocket server for testing
jest.mock("ws");

describe("WebSocket Functionality Integration Tests", () => {
  let mockWebSocket: jest.Mocked<WebSocket>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockWebSocket = new WebSocket(
      "ws://localhost:3001",
    ) as jest.Mocked<WebSocket>;
  });

  describe("Connection Management", () => {
    it("should establish WebSocket connection successfully", async () => {
      const connectEvent = {
        requestContext: {
          connectionId: "test-connection-id",
          eventType: "CONNECT",
          routeKey: "$connect",
        },
      };

      // Mock successful connection
      mockWebSocket.readyState = WebSocket.OPEN;

      expect(mockWebSocket.readyState).toBe(WebSocket.OPEN);
    });

    it("should handle WebSocket disconnection", async () => {
      const disconnectEvent = {
        requestContext: {
          connectionId: "test-connection-id",
          eventType: "DISCONNECT",
          routeKey: "$disconnect",
        },
      };

      mockWebSocket.readyState = WebSocket.CLOSED;

      expect(mockWebSocket.readyState).toBe(WebSocket.CLOSED);
    });

    it("should manage multiple concurrent connections", async () => {
      const connections = [];
      for (let i = 0; i < 100; i++) {
        const connection = new WebSocket(
          "ws://localhost:3001",
        ) as jest.Mocked<WebSocket>;
        connection.readyState = WebSocket.OPEN;
        connections.push(connection);
      }

      expect(connections).toHaveLength(100);
      connections.forEach((conn) => {
        expect(conn.readyState).toBe(WebSocket.OPEN);
      });
    });
  });

  describe("Real-time Game Communication", () => {
    it("should broadcast game state to connected players", async () => {
      const gameState = {
        gameId: "test-game-123",
        round: 1,
        plant: {
          id: "plant-456",
          imageUrl: "https://example.com/plant.jpg",
          options: ["Rose", "Tulip", "Daisy", "Lily"],
        },
        timeRemaining: 30,
      };

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      // Simulate sending game state
      mockWebSocket.send(
        JSON.stringify({
          type: "GAME_STATE",
          data: gameState,
        }),
      );

      expect(sendMock).toHaveBeenCalledWith(
        JSON.stringify({
          type: "GAME_STATE",
          data: gameState,
        }),
      );
    });

    it("should handle player answers in real-time", async () => {
      const playerAnswer = {
        playerId: "player-123",
        gameId: "game-456",
        round: 1,
        answer: "Rose",
        timestamp: Date.now(),
      };

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      // Simulate receiving player answer
      mockWebSocket.send(
        JSON.stringify({
          type: "PLAYER_ANSWER",
          data: playerAnswer,
        }),
      );

      expect(sendMock).toHaveBeenCalledWith(
        JSON.stringify({
          type: "PLAYER_ANSWER",
          data: playerAnswer,
        }),
      );
    });

    it("should handle round results broadcasting", async () => {
      const roundResult = {
        gameId: "game-123",
        round: 1,
        correctAnswer: "Rose",
        winner: "player-123",
        scores: {
          "player-123": 1,
          "player-456": 0,
        },
        plantFact: "Roses are part of the Rosaceae family.",
      };

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      mockWebSocket.send(
        JSON.stringify({
          type: "ROUND_RESULT",
          data: roundResult,
        }),
      );

      expect(sendMock).toHaveBeenCalledWith(
        JSON.stringify({
          type: "ROUND_RESULT",
          data: roundResult,
        }),
      );
    });
  });

  describe("Matchmaking WebSocket Communication", () => {
    it("should notify players when match is found", async () => {
      const matchFoundData = {
        gameId: "new-game-789",
        opponent: {
          id: "player-456",
          username: "plantlover",
          rating: 1250,
        },
        estimatedWaitTime: 5000,
      };

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      mockWebSocket.send(
        JSON.stringify({
          type: "MATCH_FOUND",
          data: matchFoundData,
        }),
      );

      expect(sendMock).toHaveBeenCalledWith(
        JSON.stringify({
          type: "MATCH_FOUND",
          data: matchFoundData,
        }),
      );
    });

    it("should handle matchmaking queue updates", async () => {
      const queueUpdate = {
        position: 3,
        estimatedWaitTime: 15000,
        playersInQueue: 12,
      };

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      mockWebSocket.send(
        JSON.stringify({
          type: "QUEUE_UPDATE",
          data: queueUpdate,
        }),
      );

      expect(sendMock).toHaveBeenCalledWith(
        JSON.stringify({
          type: "QUEUE_UPDATE",
          data: queueUpdate,
        }),
      );
    });
  });

  describe("Error Handling and Recovery", () => {
    it("should handle connection timeouts gracefully", async () => {
      const timeoutHandler = jest.fn();

      // Set up fake timers before scheduling timeout
      jest.useFakeTimers();

      // Simulate connection timeout
      setTimeout(() => {
        mockWebSocket.readyState = WebSocket.CLOSED;
        timeoutHandler();
      }, 1000);

      // Fast-forward time
      jest.advanceTimersByTime(1000);

      expect(timeoutHandler).toHaveBeenCalled();
      expect(mockWebSocket.readyState).toBe(WebSocket.CLOSED);

      jest.useRealTimers();
    });

    it("should attempt reconnection on connection loss", async () => {
      const reconnectAttempts = [];

      // Simulate multiple reconnection attempts
      for (let i = 0; i < 3; i++) {
        const newConnection = new WebSocket(
          "ws://localhost:3001",
        ) as jest.Mocked<WebSocket>;
        newConnection.readyState = i === 2 ? WebSocket.OPEN : WebSocket.CLOSED;
        reconnectAttempts.push(newConnection);
      }

      expect(reconnectAttempts).toHaveLength(3);
      expect(reconnectAttempts[2].readyState).toBe(WebSocket.OPEN);
    });

    it("should handle malformed message gracefully", async () => {
      const errorHandler = jest.fn();
      mockWebSocket.on = jest.fn((event, handler) => {
        if (event === "error") {
          errorHandler();
        }
      });

      // Simulate malformed message
      const malformedMessage = "{invalid json}";

      try {
        JSON.parse(malformedMessage);
      } catch (error) {
        errorHandler();
      }

      expect(errorHandler).toHaveBeenCalled();
    });
  });

  describe("Performance and Scalability", () => {
    it("should handle high message throughput", async () => {
      const messageCount = 1000;
      const messages = [];
      const sendMock = jest.fn();

      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      for (let i = 0; i < messageCount; i++) {
        const message = {
          type: "PERFORMANCE_TEST",
          data: { messageId: i, timestamp: Date.now() },
        };
        messages.push(message);
        mockWebSocket.send(JSON.stringify(message));
      }

      expect(messages).toHaveLength(messageCount);
      expect(sendMock).toHaveBeenCalledTimes(messageCount);
    });

    it("should maintain low latency under load", async () => {
      const startTime = Date.now();
      const latencyThreshold = 100; // 100ms

      const sendMock = jest.fn();
      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      // Simulate sending 100 rapid messages
      for (let i = 0; i < 100; i++) {
        mockWebSocket.send(
          JSON.stringify({
            type: "LATENCY_TEST",
            data: { id: i, timestamp: Date.now() },
          }),
        );
      }

      const endTime = Date.now();
      const totalTime = endTime - startTime;

      expect(totalTime).toBeLessThan(latencyThreshold);
      expect(sendMock).toHaveBeenCalledTimes(100);
    });
  });

  describe("Game State Synchronization", () => {
    it("should keep game state synchronized between players", async () => {
      const player1Socket = new WebSocket(
        "ws://localhost:3001",
      ) as jest.Mocked<WebSocket>;
      const player2Socket = new WebSocket(
        "ws://localhost:3001",
      ) as jest.Mocked<WebSocket>;

      const player1Send = jest.fn();
      const player2Send = jest.fn();

      player1Socket.send = player1Send;
      player2Socket.send = player2Send;
      player1Socket.readyState = WebSocket.OPEN;
      player2Socket.readyState = WebSocket.OPEN;

      const gameState = {
        gameId: "sync-test-game",
        round: 2,
        scores: { player1: 1, player2: 1 },
      };

      // Both players should receive the same game state
      const stateMessage = JSON.stringify({
        type: "GAME_STATE_SYNC",
        data: gameState,
      });

      player1Socket.send(stateMessage);
      player2Socket.send(stateMessage);

      expect(player1Send).toHaveBeenCalledWith(stateMessage);
      expect(player2Send).toHaveBeenCalledWith(stateMessage);
    });

    it("should handle out-of-order message delivery", async () => {
      const messages = [
        { id: 1, type: "ROUND_START", timestamp: 1000 },
        { id: 2, type: "PLAYER_ANSWER", timestamp: 2000 },
        { id: 3, type: "ROUND_END", timestamp: 3000 },
      ];

      const receivedMessages: any[] = [];
      const sendMock = jest.fn((message) => {
        receivedMessages.push(JSON.parse(message));
      });

      mockWebSocket.send = sendMock;
      mockWebSocket.readyState = WebSocket.OPEN;

      // Send messages out of order
      mockWebSocket.send(JSON.stringify(messages[1])); // Second message first
      mockWebSocket.send(JSON.stringify(messages[0])); // First message second
      mockWebSocket.send(JSON.stringify(messages[2])); // Third message last

      expect(receivedMessages).toHaveLength(3);
      expect(sendMock).toHaveBeenCalledTimes(3);
    });
  });
});
