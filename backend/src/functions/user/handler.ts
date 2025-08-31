import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import { RedisClientType, createClient } from "redis";
import {
  getRankFromRating,
  calculateLeaderboardStats,
  LeaderboardEntry,
} from "../game/eloRanking";

const dynamoDb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const redisUrl = process.env.ELASTICACHE_REDIS_URL;
let redis: RedisClientType | null = null;

const USERS_TABLE = process.env.USERS_TABLE || "botanybattle-users-dev";
const USER_STATS_TABLE =
  process.env.USER_STATS_TABLE || "botanybattle-user-stats-dev";

interface UserProfile {
  userId: string;
  username: string;
  email: string;
  displayName: string;
  avatarURL?: string;
  createdAt: string;
  updatedAt: string;
  isPrivate: boolean;
  bio?: string;
}

interface UserStats {
  userId: string;
  eloRating: number;
  rank: string;
  totalGamesPlayed: number;
  totalWins: number;
  totalLosses: number;
  currentStreak: number;
  longestStreak: number;
  plantsIdentified: number;
  accuracyRate: number;
  averageResponseTime: number;
  lastGameAt?: string;
  rankHistory: Array<{
    rank: string;
    achievedAt: string;
    eloRating: number;
  }>;
}

interface UserCurrency {
  coins: number;
  gems: number;
  tokens: number;
}

async function initRedis(): Promise<RedisClientType> {
  if (!redis && redisUrl) {
    redis = createClient({ url: redisUrl });
    await redis.connect();
  }
  return redis as RedisClientType;
}

/**
 * Get user profile with current stats
 */
export async function getUserProfile(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return {
        statusCode: 401,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Unauthorized" }),
      };
    }

    // Get user profile
    const profileResult = await dynamoDb.send(
      new GetCommand({
        TableName: USERS_TABLE,
        Key: { userId },
      }),
    );

    if (!profileResult.Item) {
      return {
        statusCode: 404,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "User not found" }),
      };
    }

    // Get user stats
    const statsResult = await dynamoDb.send(
      new GetCommand({
        TableName: USER_STATS_TABLE,
        Key: { userId },
      }),
    );

    // Initialize stats if they don't exist
    let userStats: UserStats;
    if (!statsResult.Item) {
      userStats = await initializeUserStats(userId);
    } else {
      userStats = statsResult.Item as UserStats;
    }

    // Combine profile and stats
    const userProfile = profileResult.Item as UserProfile;
    const response = {
      user: {
        id: userId,
        username: userProfile.username,
        email: userProfile.email,
        displayName: userProfile.displayName,
        avatarURL: userProfile.avatarURL,
        createdAt: userProfile.createdAt,
        stats: {
          totalGamesPlayed: userStats.totalGamesPlayed,
          totalWins: userStats.totalWins,
          currentStreak: userStats.currentStreak,
          longestStreak: userStats.longestStreak,
          eloRating: userStats.eloRating,
          rank: userStats.rank,
          plantsIdentified: userStats.plantsIdentified,
          accuracyRate: userStats.accuracyRate,
        },
        currency: {
          coins: 100, // Default currency
          gems: 0,
          tokens: 0,
        },
      },
    };

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error("Error getting user profile:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
}

/**
 * Update user profile
 */
export async function updateUserProfile(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return {
        statusCode: 401,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Unauthorized" }),
      };
    }

    const body = JSON.parse(event.body || "{}");
    const { displayName, bio, isPrivate } = body;

    const updateExpression = [];
    const expressionAttributeValues: any = {};
    const expressionAttributeNames: any = {};

    if (displayName !== undefined) {
      updateExpression.push("#displayName = :displayName");
      expressionAttributeNames["#displayName"] = "displayName";
      expressionAttributeValues[":displayName"] = displayName;
    }

    if (bio !== undefined) {
      updateExpression.push("bio = :bio");
      expressionAttributeValues[":bio"] = bio;
    }

    if (isPrivate !== undefined) {
      updateExpression.push("isPrivate = :isPrivate");
      expressionAttributeValues[":isPrivate"] = isPrivate;
    }

    updateExpression.push("updatedAt = :updatedAt");
    expressionAttributeValues[":updatedAt"] = new Date().toISOString();

    await dynamoDb.send(
      new UpdateCommand({
        TableName: USERS_TABLE,
        Key: { userId },
        UpdateExpression: `SET ${updateExpression.join(", ")}`,
        ExpressionAttributeValues: expressionAttributeValues,
        ExpressionAttributeNames:
          Object.keys(expressionAttributeNames).length > 0
            ? expressionAttributeNames
            : undefined,
      }),
    );

    // Return updated profile
    return getUserProfile(event);
  } catch (error) {
    console.error("Error updating user profile:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
}

/**
 * Get leaderboard with ELO rankings
 */
export async function getLeaderboard(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const limit = parseInt(event.queryStringParameters?.limit || "50");
    const offset = parseInt(event.queryStringParameters?.offset || "0");

    // Try to get from cache first
    const redis = await initRedis();
    const cacheKey = `leaderboard:${limit}:${offset}`;

    if (redis) {
      const cached = await redis.get(cacheKey);
      if (cached) {
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json" },
          body: cached,
        };
      }
    }

    // Query top players by ELO rating
    const result = await dynamoDb.send(
      new QueryCommand({
        TableName: USER_STATS_TABLE,
        IndexName: "EloRatingIndex", // GSI on eloRating
        KeyConditionExpression: "rankType = :rankType",
        ExpressionAttributeValues: {
          ":rankType": "GLOBAL",
        },
        ScanIndexForward: false, // Descending order
        Limit: limit + offset,
      }),
    );

    if (!result.Items) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ entries: [] }),
      };
    }

    // Get user profiles for leaderboard entries
    const leaderboardEntries: LeaderboardEntry[] = [];
    const itemsToProcess = result.Items.slice(offset, offset + limit);

    for (let i = 0; i < itemsToProcess.length; i++) {
      const stats = itemsToProcess[i] as UserStats;

      // Get user profile
      const profileResult = await dynamoDb.send(
        new GetCommand({
          TableName: USERS_TABLE,
          Key: { userId: stats.userId },
        }),
      );

      if (profileResult.Item) {
        const profile = profileResult.Item as UserProfile;
        const leaderboardStats = calculateLeaderboardStats(
          stats.eloRating,
          stats.totalWins,
          stats.totalLosses,
          stats.currentStreak,
        );

        leaderboardEntries.push({
          rank: offset + i + 1,
          userId: stats.userId,
          username: profile.username,
          displayName: profile.displayName,
          eloRating: stats.eloRating,
          rankTitle: stats.rank,
          totalWins: stats.totalWins,
          totalGamesPlayed: stats.totalGamesPlayed,
          winRate: leaderboardStats.winRate || 0,
          currentStreak: stats.currentStreak,
          avatarURL: profile.avatarURL,
        });
      }
    }

    const response = { entries: leaderboardEntries };

    // Cache for 5 minutes
    if (redis) {
      await redis.setEx(cacheKey, 300, JSON.stringify(response));
    }

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error("Error getting leaderboard:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
}

/**
 * Get user achievements and detailed stats
 */
export async function getUserStats(
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;
    if (!userId) {
      return {
        statusCode: 401,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Unauthorized" }),
      };
    }

    const statsResult = await dynamoDb.send(
      new GetCommand({
        TableName: USER_STATS_TABLE,
        Key: { userId },
      }),
    );

    if (!statsResult.Item) {
      // Initialize stats if they don't exist
      const userStats = await initializeUserStats(userId);
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ achievements: [] }),
      };
    }

    const userStats = statsResult.Item as UserStats;
    const achievements = generateAchievements(userStats);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ achievements }),
    };
  } catch (error) {
    console.error("Error getting user stats:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
}

/**
 * Update user ELO rating after a game
 */
export async function updateUserELO(
  userId: string,
  newRating: number,
  ratingChange: number,
  gameResult: "win" | "loss",
  gameStats: {
    accuracyRate: number;
    averageResponseTime: number;
    plantsIdentified: number;
  },
): Promise<void> {
  try {
    const newRank = getRankFromRating(newRating);
    const now = new Date().toISOString();

    // Get current stats
    const currentStats = await dynamoDb.send(
      new GetCommand({
        TableName: USER_STATS_TABLE,
        Key: { userId },
      }),
    );

    let stats: UserStats;
    if (!currentStats.Item) {
      stats = await initializeUserStats(userId);
    } else {
      stats = currentStats.Item as UserStats;
    }

    // Update streak
    let currentStreak = stats.currentStreak;
    if (gameResult === "win") {
      currentStreak = currentStreak >= 0 ? currentStreak + 1 : 1;
    } else {
      currentStreak = currentStreak <= 0 ? currentStreak - 1 : -1;
    }

    const longestStreak = Math.max(
      stats.longestStreak,
      Math.abs(currentStreak),
    );

    // Check for rank change
    const rankHistory = [...stats.rankHistory];
    if (newRank !== stats.rank) {
      rankHistory.push({
        rank: newRank,
        achievedAt: now,
        eloRating: newRating,
      });
    }

    // Update stats
    await dynamoDb.send(
      new UpdateCommand({
        TableName: USER_STATS_TABLE,
        Key: { userId },
        UpdateExpression: `SET 
        eloRating = :eloRating,
        #rank = :rank,
        totalGamesPlayed = totalGamesPlayed + :one,
        totalWins = totalWins + :wins,
        totalLosses = totalLosses + :losses,
        currentStreak = :currentStreak,
        longestStreak = :longestStreak,
        plantsIdentified = plantsIdentified + :plantsIdentified,
        accuracyRate = :accuracyRate,
        averageResponseTime = :averageResponseTime,
        lastGameAt = :lastGameAt,
        rankHistory = :rankHistory,
        rankType = :rankType`,
        ExpressionAttributeNames: {
          "#rank": "rank",
        },
        ExpressionAttributeValues: {
          ":eloRating": newRating,
          ":rank": newRank,
          ":one": 1,
          ":wins": gameResult === "win" ? 1 : 0,
          ":losses": gameResult === "loss" ? 1 : 0,
          ":currentStreak": currentStreak,
          ":longestStreak": longestStreak,
          ":plantsIdentified": gameStats.plantsIdentified,
          ":accuracyRate": gameStats.accuracyRate,
          ":averageResponseTime": gameStats.averageResponseTime,
          ":lastGameAt": now,
          ":rankHistory": rankHistory,
          ":rankType": "GLOBAL",
        },
      }),
    );

    // Invalidate leaderboard cache
    const redis = await initRedis();
    if (redis) {
      const keys = await redis.keys("leaderboard:*");
      if (keys.length > 0) {
        await redis.del(keys);
      }
    }
  } catch (error) {
    console.error("Error updating user ELO:", error);
    throw error;
  }
}

/**
 * Initialize user stats for new users
 */
async function initializeUserStats(userId: string): Promise<UserStats> {
  const stats: UserStats = {
    userId,
    eloRating: 1000, // Starting ELO
    rank: getRankFromRating(1000),
    totalGamesPlayed: 0,
    totalWins: 0,
    totalLosses: 0,
    currentStreak: 0,
    longestStreak: 0,
    plantsIdentified: 0,
    accuracyRate: 0,
    averageResponseTime: 0,
    rankHistory: [
      {
        rank: getRankFromRating(1000),
        achievedAt: new Date().toISOString(),
        eloRating: 1000,
      },
    ],
  };

  await dynamoDb.send(
    new UpdateCommand({
      TableName: USER_STATS_TABLE,
      Key: { userId },
      UpdateExpression: `SET 
      eloRating = :eloRating,
      #rank = :rank,
      totalGamesPlayed = :totalGamesPlayed,
      totalWins = :totalWins,
      totalLosses = :totalLosses,
      currentStreak = :currentStreak,
      longestStreak = :longestStreak,
      plantsIdentified = :plantsIdentified,
      accuracyRate = :accuracyRate,
      averageResponseTime = :averageResponseTime,
      rankHistory = :rankHistory,
      rankType = :rankType`,
      ExpressionAttributeNames: {
        "#rank": "rank",
      },
      ExpressionAttributeValues: {
        ":eloRating": stats.eloRating,
        ":rank": stats.rank,
        ":totalGamesPlayed": stats.totalGamesPlayed,
        ":totalWins": stats.totalWins,
        ":totalLosses": stats.totalLosses,
        ":currentStreak": stats.currentStreak,
        ":longestStreak": stats.longestStreak,
        ":plantsIdentified": stats.plantsIdentified,
        ":accuracyRate": stats.accuracyRate,
        ":averageResponseTime": stats.averageResponseTime,
        ":rankHistory": stats.rankHistory,
        ":rankType": "GLOBAL",
      },
    }),
  );

  return stats;
}

/**
 * Generate achievements based on user stats
 */
function generateAchievements(stats: UserStats) {
  const achievements = [];

  // First Win
  achievements.push({
    id: "first_win",
    title: "First Victory",
    description: "Win your first game",
    iconName: "trophy",
    isUnlocked: stats.totalWins >= 1,
    unlockedDate:
      stats.totalWins >= 1 ? stats.rankHistory[0]?.achievedAt : null,
    progress: Math.min(stats.totalWins, 1),
    maxProgress: 1,
  });

  // Plant Identifier achievements
  achievements.push({
    id: "plant_novice",
    title: "Plant Novice",
    description: "Identify 50 plants",
    iconName: "leaf",
    isUnlocked: stats.plantsIdentified >= 50,
    unlockedDate: stats.plantsIdentified >= 50 ? stats.lastGameAt : null,
    progress: Math.min(stats.plantsIdentified, 50),
    maxProgress: 50,
  });

  achievements.push({
    id: "plant_expert",
    title: "Plant Expert",
    description: "Identify 200 plants",
    iconName: "leaf.fill",
    isUnlocked: stats.plantsIdentified >= 200,
    unlockedDate: stats.plantsIdentified >= 200 ? stats.lastGameAt : null,
    progress: Math.min(stats.plantsIdentified, 200),
    maxProgress: 200,
  });

  // Winning streak
  achievements.push({
    id: "streak_master",
    title: "Streak Master",
    description: "Win 5 games in a row",
    iconName: "flame",
    isUnlocked: stats.longestStreak >= 5,
    unlockedDate: stats.longestStreak >= 5 ? stats.lastGameAt : null,
    progress: Math.min(stats.longestStreak, 5),
    maxProgress: 5,
  });

  // Rank achievements
  const rankAchievements = [
    {
      rank: "Sprout",
      title: "Growing Strong",
      description: "Reach Sprout rank",
    },
    {
      rank: "Green Thumb",
      title: "Green Thumb",
      description: "Reach Green Thumb rank",
    },
    {
      rank: "Gardener",
      title: "Master Gardener",
      description: "Reach Gardener rank",
    },
    {
      rank: "Botanist",
      title: "Professional Botanist",
      description: "Reach Botanist rank",
    },
  ];

  for (const rankAch of rankAchievements) {
    const hasReached = stats.rankHistory.some((r) => r.rank === rankAch.rank);
    achievements.push({
      id: `rank_${rankAch.rank.toLowerCase().replace(" ", "_")}`,
      title: rankAch.title,
      description: rankAch.description,
      iconName: "star",
      isUnlocked: hasReached,
      unlockedDate: hasReached
        ? stats.rankHistory.find((r) => r.rank === rankAch.rank)?.achievedAt
        : null,
      progress: hasReached ? 1 : 0,
      maxProgress: 1,
    });
  }

  return achievements;
}

// Main Lambda handler
export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  const { httpMethod, path } = event;

  try {
    switch (true) {
      case httpMethod === "GET" && path.includes("/profile"):
        return await getUserProfile(event);
      case httpMethod === "PUT" && path.includes("/profile"):
        return await updateUserProfile(event);
      case httpMethod === "GET" && path.includes("/leaderboard"):
        return await getLeaderboard(event);
      case httpMethod === "GET" && path.includes("/stats"):
        return await getUserStats(event);
      default:
        return {
          statusCode: 404,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ error: "Route not found" }),
        };
    }
  } catch (error) {
    console.error("User handler error:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: "Internal server error" }),
    };
  }
};

// Lambda handler exports
export { getUserProfile as profile };
export { updateUserProfile as update };
export { getLeaderboard as leaderboard };
export { getUserStats as stats };

// updateUserELO is already exported as a function declaration above
