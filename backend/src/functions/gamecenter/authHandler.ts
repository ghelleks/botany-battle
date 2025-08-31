import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
} from "@aws-sdk/lib-dynamodb";
import crypto from "crypto";

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

export interface GameCenterTokenData {
  playerId: string;
  signature: string;
  salt: string;
  timestamp: string;
  bundleId: string;
}

export interface User {
  id: string;
  username: string;
  displayName: string;
  email?: string;
  avatarURL?: string;
  createdAt: string;
  stats: {
    totalGamesPlayed: number;
    totalWins: number;
    currentStreak: number;
    longestStreak: number;
    eloRating: number;
    rank: string;
    plantsIdentified: number;
    accuracyRate: number;
  };
  currency: {
    coins: number;
    gems: number;
    tokens: number;
  };
}

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
  };

  try {
    if (event.httpMethod === "OPTIONS") {
      return {
        statusCode: 200,
        headers,
        body: "",
      };
    }

    if (event.httpMethod !== "POST") {
      return {
        statusCode: 405,
        headers,
        body: JSON.stringify({ error: "Method not allowed" }),
      };
    }

    const { token } = JSON.parse(event.body || "{}");

    if (!token) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: "Game Center token is required" }),
      };
    }

    // Decode the Game Center token with proper error handling
    let tokenData: GameCenterTokenData;
    try {
      tokenData = decodeGameCenterToken(token);
    } catch (error) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: "Invalid Game Center token" }),
      };
    }

    // Validate the token (in production, you would verify the signature with Apple)
    const isValid = await validateGameCenterToken(tokenData);

    if (!isValid) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: "Invalid Game Center token" }),
      };
    }

    // Get or create user with proper error handling
    let user: User;
    try {
      user = await getOrCreateUser(tokenData.playerId);
    } catch (error) {
      console.error("Database error in getOrCreateUser:", error);
      return {
        statusCode: 500,
        headers,
        body: JSON.stringify({
          error: "Internal server error",
          message: error instanceof Error ? error.message : "Unknown error",
        }),
      };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        user,
        authenticated: true,
      }),
    };
  } catch (error) {
    console.error("Game Center authentication error:", error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error",
      }),
    };
  }
};

function decodeGameCenterToken(token: string): GameCenterTokenData {
  try {
    const decodedData = Buffer.from(token, "base64").toString("utf-8");
    return JSON.parse(decodedData);
  } catch (error) {
    throw new Error("Invalid token format");
  }
}

async function validateGameCenterToken(
  tokenData: GameCenterTokenData,
): Promise<boolean> {
  // Basic validation checks
  if (
    !tokenData.playerId ||
    !tokenData.signature ||
    !tokenData.salt ||
    !tokenData.timestamp
  ) {
    return false;
  }

  // Check if token is not too old (5 minutes) and not from the future
  const tokenTime = parseInt(tokenData.timestamp);
  const currentTime = Math.floor(Date.now() / 1000);
  const timeDiff = currentTime - tokenTime;

  // Reject tokens that are too old (more than 5 minutes)
  if (timeDiff > 300) {
    // 5 minutes
    console.warn("Token is too old:", timeDiff);
    return false;
  }

  // Reject tokens from the future (more than 1 minute ahead to account for clock skew)
  if (timeDiff < -60) {
    // 1 minute in the future
    console.warn("Token is from the future:", timeDiff);
    return false;
  }

  // Validate bundle ID
  if (tokenData.bundleId !== "com.botanybattle.app") {
    console.warn("Invalid bundle ID:", tokenData.bundleId);
    return false;
  }

  // TODO: In production, verify the signature with Apple's public key
  // For now, we'll accept tokens that pass basic validation
  // Apple provides documentation on how to verify Game Center signatures:
  // https://developer.apple.com/documentation/gamekit/gklocalplayer/1515407-generateidentityverificationsign

  return true;
}

async function getOrCreateUser(playerId: string): Promise<User> {
  try {
    // Try to get existing user
    const getResult = await docClient.send(
      new GetCommand({
        TableName: process.env.DYNAMODB_TABLE,
        Key: {
          id: playerId,
        },
      }),
    );

    if (getResult.Item) {
      return getResult.Item as User;
    }

    // Create new user
    const newUser: User = {
      id: playerId,
      username: `Player_${playerId.slice(-8)}`, // Use last 8 chars of player ID
      displayName: `Player_${playerId.slice(-8)}`,
      createdAt: new Date().toISOString(),
      stats: {
        totalGamesPlayed: 0,
        totalWins: 0,
        currentStreak: 0,
        longestStreak: 0,
        eloRating: 1000,
        rank: "Seedling",
        plantsIdentified: 0,
        accuracyRate: 0.0,
      },
      currency: {
        coins: 100,
        gems: 0,
        tokens: 0,
      },
    };

    await docClient.send(
      new PutCommand({
        TableName: process.env.DYNAMODB_TABLE,
        Item: newUser,
      }),
    );

    return newUser;
  } catch (error) {
    console.error("Error getting/creating user:", error);
    throw error;
  }
}
