import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
  APIGatewayProxyWebsocketEventV2,
} from "aws-lambda";
import {
  DynamoDBClient,
  PutItemCommand,
  GetItemCommand,
  UpdateItemCommand,
} from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";
import {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} from "@aws-sdk/client-apigatewaymanagementapi";
import Redis from "ioredis";
import {
  updateELORatings,
  PlayerRating,
  GameResult,
  getMatchmakingRange,
} from "./eloRanking";
import { updateUserELO } from "../user/handler";

const dynamodb = new DynamoDBClient({ region: process.env.REGION });
const dynamoDbDoc = DynamoDBDocumentClient.from(dynamodb);
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || "6379"),
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
});

const USER_STATS_TABLE =
  process.env.USER_STATS_TABLE || "botanybattle-user-stats-dev";

interface GameState {
  gameId: string;
  players: string[];
  currentRound: number;
  maxRounds: number;
  status: "waiting" | "active" | "completed";
  scores: Record<string, number>;
  playerStats: Record<
    string,
    {
      correctAnswers: number;
      totalAnswers: number;
      averageResponseTime: number;
      eloRating: number;
    }
  >;
  roundStartTime?: number;
  gameStartTime: number;
  gameEndTime?: number;
  currentQuestion?: {
    plantId: string;
    options: string[];
    correctAnswer: string;
    questionStartTime: number;
  };
  winner?: string;
  eloChanges?: Record<string, number>;
}

export const handler = async (
  event: APIGatewayProxyEvent | APIGatewayProxyWebsocketEventV2,
): Promise<APIGatewayProxyResult> => {
  try {
    const { requestContext } = event;

    if ("routeKey" in requestContext) {
      return await handleWebSocketEvent(
        event as APIGatewayProxyWebsocketEventV2,
      );
    } else {
      return await handleHttpEvent(event as APIGatewayProxyEvent);
    }
  } catch (error) {
    console.error("Game handler error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error",
      }),
    };
  }
};

async function handleHttpEvent(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  const userId = event.requestContext.authorizer?.claims?.sub;
  if (!userId) {
    return {
      statusCode: 401,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Unauthorized" }),
    };
  }

  const body = JSON.parse(event.body || "{}");
  const { action, gameId, answer } = body;

  switch (action) {
    case "findMatch":
      return await findMatch(userId);
    case "joinGame":
      return await joinGame(userId, gameId);
    case "submitAnswer":
      return await submitAnswer(userId, gameId, answer);
    case "getGameState":
      return await getGameState(gameId);
    default:
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({ error: "Invalid action" }),
      };
  }
}

async function handleWebSocketEvent(
  event: APIGatewayProxyWebsocketEventV2,
): Promise<APIGatewayProxyResult> {
  const { routeKey, connectionId } = event.requestContext;
  const userId = event.queryStringParameters?.userId;

  switch (routeKey) {
    case "$connect":
      await handleConnect(connectionId!, userId);
      break;
    case "$disconnect":
      await handleDisconnect(connectionId!);
      break;
    case "$default":
      await handleMessage(connectionId!, event.body);
      break;
  }

  return { statusCode: 200, body: "OK" };
}

async function findMatch(userId: string): Promise<APIGatewayProxyResult> {
  try {
    // Get user's current ELO rating
    const userStats = await getUserStats(userId);
    const userRating = userStats?.eloRating || 1000;

    // Try to find an opponent with similar ELO rating
    const opponent = await findELOBasedOpponent(userId, userRating);

    if (opponent) {
      // Remove opponent from queue
      await removeFromMatchmakingQueue(opponent.userId);

      // Create game with both players
      const gameId = `game_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      const gameState: GameState = {
        gameId,
        players: [opponent.userId, userId],
        currentRound: 1,
        maxRounds: 10,
        status: "active",
        scores: { [opponent.userId]: 0, [userId]: 0 },
        playerStats: {
          [opponent.userId]: {
            correctAnswers: 0,
            totalAnswers: 0,
            averageResponseTime: 0,
            eloRating: opponent.eloRating,
          },
          [userId]: {
            correctAnswers: 0,
            totalAnswers: 0,
            averageResponseTime: 0,
            eloRating: userRating,
          },
        },
        gameStartTime: Date.now(),
      };

      await saveGameState(gameState);

      // Notify both players via WebSocket
      await notifyGameStart(gameState);

      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({
          gameId,
          opponent: opponent.userId,
          status: "matched",
          opponentRating: opponent.eloRating,
          yourRating: userRating,
        }),
      };
    } else {
      // Add user to matchmaking queue with timestamp
      await addToMatchmakingQueue(userId, userRating);

      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({
          status: "waiting",
          rating: userRating,
          estimatedWaitTime: "30-60 seconds",
        }),
      };
    }
  } catch (error) {
    console.error("Error in findMatch:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Matchmaking failed" }),
    };
  }
}

async function joinGame(
  userId: string,
  gameId: string,
): Promise<APIGatewayProxyResult> {
  const gameState = await loadGameState(gameId);
  if (!gameState) {
    return {
      statusCode: 404,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Game not found" }),
    };
  }

  if (!gameState.players.includes(userId)) {
    return {
      statusCode: 403,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Not authorized to join this game" }),
    };
  }

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(gameState),
  };
}

async function submitAnswer(
  userId: string,
  gameId: string,
  answer: string,
): Promise<APIGatewayProxyResult> {
  const gameState = await loadGameState(gameId);
  if (!gameState || !gameState.players.includes(userId)) {
    return {
      statusCode: 404,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Invalid game or player" }),
    };
  }

  if (gameState.status !== "active") {
    return {
      statusCode: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Game is not active" }),
    };
  }

  const now = Date.now();
  const responseTime = gameState.currentQuestion?.questionStartTime
    ? now - gameState.currentQuestion.questionStartTime
    : 0;

  const isCorrect = gameState.currentQuestion?.correctAnswer === answer;

  // Update player stats
  const playerStats = gameState.playerStats[userId];
  playerStats.totalAnswers += 1;
  if (isCorrect) {
    playerStats.correctAnswers += 1;
    gameState.scores[userId] += 100;
  }

  // Update average response time
  const totalResponseTime =
    playerStats.averageResponseTime * (playerStats.totalAnswers - 1) +
    responseTime;
  playerStats.averageResponseTime = Math.round(
    totalResponseTime / playerStats.totalAnswers,
  );

  // Check if round should end or game should continue
  const allPlayersAnswered = gameState.players.every((playerId) => {
    // This is simplified - in reality you'd track per-round answers
    return true; // For now, assume round ends after any answer
  });

  let gameComplete = false;
  if (gameState.currentRound >= gameState.maxRounds) {
    gameState.status = "completed";
    gameState.gameEndTime = now;
    gameComplete = true;

    // Determine winner and update ELO ratings
    await finalizeGame(gameState);
  } else if (allPlayersAnswered) {
    gameState.currentRound += 1;
    // Generate next question would go here
  }

  await saveGameState(gameState);

  // Notify players of answer result
  await notifyAnswerResult(gameState, userId, isCorrect, responseTime);

  const response = {
    correct: isCorrect,
    score: gameState.scores[userId],
    responseTime,
    currentRound: gameState.currentRound,
    maxRounds: gameState.maxRounds,
    gameComplete,
    ...(gameComplete && {
      finalScore: gameState.scores[userId],
      winner: gameState.winner,
      eloChange: gameState.eloChanges?.[userId],
    }),
  };

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(response),
  };
}

async function getGameState(gameId: string): Promise<APIGatewayProxyResult> {
  const gameState = await loadGameState(gameId);
  if (!gameState) {
    return {
      statusCode: 404,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Game not found" }),
    };
  }

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify(gameState),
  };
}

async function saveGameState(gameState: GameState): Promise<void> {
  await dynamodb.send(
    new PutItemCommand({
      TableName: process.env.DYNAMODB_TABLE,
      Item: {
        id: { S: gameState.gameId },
        userId: { S: gameState.players[0] },
        gameData: { S: JSON.stringify(gameState) },
        ttl: { N: Math.floor(Date.now() / 1000 + 24 * 60 * 60).toString() },
      },
    }),
  );

  await redis.setex(
    `game:${gameState.gameId}`,
    3600,
    JSON.stringify(gameState),
  );
}

async function loadGameState(gameId: string): Promise<GameState | null> {
  try {
    const cached = await redis.get(`game:${gameId}`);
    if (cached) {
      return JSON.parse(cached);
    }

    const result = await dynamodb.send(
      new GetItemCommand({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { id: { S: gameId } },
      }),
    );

    if (result.Item) {
      const gameState = JSON.parse(result.Item.gameData.S!);
      await redis.setex(`game:${gameId}`, 3600, JSON.stringify(gameState));
      return gameState;
    }

    return null;
  } catch (error) {
    console.error("Error loading game state:", error);
    return null;
  }
}

async function handleConnect(
  connectionId: string,
  userId?: string,
): Promise<void> {
  if (userId) {
    await redis.setex(`connection:${connectionId}`, 3600, userId);
    await redis.setex(`user:${userId}:connection`, 3600, connectionId);
  }
}

async function handleDisconnect(connectionId: string): Promise<void> {
  const userId = await redis.get(`connection:${connectionId}`);
  if (userId) {
    await redis.del(`connection:${connectionId}`);
    await redis.del(`user:${userId}:connection`);
  }
}

async function handleMessage(
  connectionId: string,
  body: string | null,
): Promise<void> {
  if (!body) return;

  try {
    const message = JSON.parse(body);
    console.log("WebSocket message:", message);
  } catch (error) {
    console.error("Error parsing WebSocket message:", error);
  }
}

// ELO and Matchmaking Helper Functions

async function getUserStats(
  userId: string,
): Promise<{ eloRating: number; gamesPlayed: number } | null> {
  try {
    const result = await dynamoDbDoc.send(
      new GetCommand({
        TableName: USER_STATS_TABLE,
        Key: { userId },
      }),
    );

    if (result.Item) {
      return {
        eloRating: result.Item.eloRating || 1000,
        gamesPlayed: result.Item.totalGamesPlayed || 0,
      };
    }

    return { eloRating: 1000, gamesPlayed: 0 }; // Default for new users
  } catch (error) {
    console.error("Error getting user stats:", error);
    return { eloRating: 1000, gamesPlayed: 0 };
  }
}

async function findELOBasedOpponent(
  userId: string,
  userRating: number,
): Promise<{ userId: string; eloRating: number; waitTime: number } | null> {
  try {
    // Get all waiting players
    const waitingPlayers = await redis.hgetall("matchmaking:players");

    if (Object.keys(waitingPlayers).length === 0) {
      return null;
    }

    let bestOpponent: {
      userId: string;
      eloRating: number;
      waitTime: number;
    } | null = null;
    let smallestRatingDiff = Infinity;

    for (const [playerId, playerData] of Object.entries(waitingPlayers)) {
      if (playerId === userId) continue;

      const data = JSON.parse(playerData);
      const opponentRating = data.eloRating;
      const joinTime = data.joinTime;
      const waitTime = Date.now() - joinTime;

      // Calculate acceptable rating range based on wait time
      const { min, max } = getMatchmakingRange(userRating, waitTime);

      // Check if opponent is within acceptable range
      if (opponentRating >= min && opponentRating <= max) {
        const ratingDiff = Math.abs(userRating - opponentRating);

        // Prefer closer rating matches, but factor in wait time
        const matchScore = ratingDiff - waitTime / 1000; // Reduce score for longer wait

        if (matchScore < smallestRatingDiff) {
          smallestRatingDiff = matchScore;
          bestOpponent = {
            userId: playerId,
            eloRating: opponentRating,
            waitTime,
          };
        }
      }
    }

    return bestOpponent;
  } catch (error) {
    console.error("Error finding ELO-based opponent:", error);
    return null;
  }
}

async function addToMatchmakingQueue(
  userId: string,
  eloRating: number,
): Promise<void> {
  const playerData = {
    eloRating,
    joinTime: Date.now(),
  };

  await redis.hset("matchmaking:players", userId, JSON.stringify(playerData));
  await redis.expire("matchmaking:players", 600); // 10 minute expiry
}

async function removeFromMatchmakingQueue(userId: string): Promise<void> {
  await redis.hdel("matchmaking:players", userId);
}

async function finalizeGame(gameState: GameState): Promise<void> {
  try {
    // Determine winner
    const [player1, player2] = gameState.players;
    const score1 = gameState.scores[player1];
    const score2 = gameState.scores[player2];

    let winner: string;
    let loser: string;

    if (score1 > score2) {
      winner = player1;
      loser = player2;
    } else if (score2 > score1) {
      winner = player2;
      loser = player1;
    } else {
      // Handle tie - higher accuracy wins, then faster average response time
      const stats1 = gameState.playerStats[player1];
      const stats2 = gameState.playerStats[player2];

      const accuracy1 = stats1.correctAnswers / stats1.totalAnswers;
      const accuracy2 = stats2.correctAnswers / stats2.totalAnswers;

      if (accuracy1 > accuracy2) {
        winner = player1;
        loser = player2;
      } else if (accuracy2 > accuracy1) {
        winner = player2;
        loser = player1;
      } else {
        // Same accuracy, faster response time wins
        if (stats1.averageResponseTime < stats2.averageResponseTime) {
          winner = player1;
          loser = player2;
        } else {
          winner = player2;
          loser = player1;
        }
      }
    }

    gameState.winner = winner;

    // Calculate ELO changes
    const winnerStats = gameState.playerStats[winner];
    const loserStats = gameState.playerStats[loser];

    const winnerRating: PlayerRating = {
      userId: winner,
      currentRating: winnerStats.eloRating,
      gamesPlayed: (await getUserStats(winner))?.gamesPlayed || 0,
      rank: "",
    };

    const loserRating: PlayerRating = {
      userId: loser,
      currentRating: loserStats.eloRating,
      gamesPlayed: (await getUserStats(loser))?.gamesPlayed || 0,
      rank: "",
    };

    const gameResult: GameResult = {
      winner,
      loser,
      winnerScore: gameState.scores[winner],
      loserScore: gameState.scores[loser],
      roundsPlayed: gameState.maxRounds,
      averageResponseTime: winnerStats.averageResponseTime,
      accuracyRate: winnerStats.correctAnswers / winnerStats.totalAnswers,
    };

    const eloResults = updateELORatings(winnerRating, loserRating, gameResult);

    // Store ELO changes in game state
    gameState.eloChanges = {
      [winner]: eloResults.winner.ratingChange,
      [loser]: eloResults.loser.ratingChange,
    };

    // Update user ELO ratings in database
    await updateUserELO(
      winner,
      eloResults.winner.newRating,
      eloResults.winner.ratingChange,
      "win",
      {
        accuracyRate: winnerStats.correctAnswers / winnerStats.totalAnswers,
        averageResponseTime: winnerStats.averageResponseTime,
        plantsIdentified: winnerStats.correctAnswers,
      },
    );

    await updateUserELO(
      loser,
      eloResults.loser.newRating,
      eloResults.loser.ratingChange,
      "loss",
      {
        accuracyRate: loserStats.correctAnswers / loserStats.totalAnswers,
        averageResponseTime: loserStats.averageResponseTime,
        plantsIdentified: loserStats.correctAnswers,
      },
    );

    // Notify players of game end
    await notifyGameEnd(gameState);
  } catch (error) {
    console.error("Error finalizing game:", error);
  }
}

// WebSocket Notification Functions

async function notifyGameStart(gameState: GameState): Promise<void> {
  const message = {
    type: "gameStarted",
    gameId: gameState.gameId,
    players: gameState.players,
    currentRound: gameState.currentRound,
    maxRounds: gameState.maxRounds,
  };

  for (const playerId of gameState.players) {
    await sendWebSocketMessage(playerId, message);
  }
}

async function notifyAnswerResult(
  gameState: GameState,
  userId: string,
  correct: boolean,
  responseTime: number,
): Promise<void> {
  const message = {
    type: "answerResult",
    gameId: gameState.gameId,
    userId,
    correct,
    responseTime,
    currentScores: gameState.scores,
    currentRound: gameState.currentRound,
  };

  for (const playerId of gameState.players) {
    await sendWebSocketMessage(playerId, message);
  }
}

async function notifyGameEnd(gameState: GameState): Promise<void> {
  const message = {
    type: "gameEnded",
    gameId: gameState.gameId,
    winner: gameState.winner,
    finalScores: gameState.scores,
    eloChanges: gameState.eloChanges,
    gameStats: gameState.playerStats,
  };

  for (const playerId of gameState.players) {
    await sendWebSocketMessage(playerId, message);
  }
}

async function sendWebSocketMessage(
  userId: string,
  message: any,
): Promise<void> {
  try {
    const connectionId = await redis.get(`user:${userId}:connection`);
    if (!connectionId) return;

    const apiGateway = new ApiGatewayManagementApiClient({
      endpoint: process.env.WEBSOCKET_API_ENDPOINT,
    });

    await apiGateway.send(
      new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify(message),
      }),
    );
  } catch (error) {
    console.error(`Error sending WebSocket message to ${userId}:`, error);
    // Connection might be stale, remove it
    const connectionId = await redis.get(`user:${userId}:connection`);
    if (connectionId) {
      await redis.del(`user:${userId}:connection`);
      await redis.del(`connection:${connectionId}`);
    }
  }
}

// Export functions for testing
export {
  getUserStats,
  findELOBasedOpponent,
  addToMatchmakingQueue,
  removeFromMatchmakingQueue,
  finalizeGame,
};
