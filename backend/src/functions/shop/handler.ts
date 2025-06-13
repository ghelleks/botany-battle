import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  UpdateItemCommand,
  TransactWriteItemsCommand,
} from "@aws-sdk/client-dynamodb";
import Redis from "ioredis";
import { createEconomyBalancer } from "../../utils/economyBalancer";

const dynamodb = new DynamoDBClient({ region: process.env.REGION });
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || "6379"),
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
});
const economyBalancer = createEconomyBalancer();

interface ShopItem {
  id: string;
  name: string;
  description: string;
  price: number;
  currency: "coins" | "gems";
  category: "powerup" | "cosmetic" | "booster";
  icon: string;
  rarity: "common" | "rare" | "epic" | "legendary";
  effects?: {
    type: string;
    value: number;
    duration?: number;
  }[];
}

interface UserInventory {
  userId: string;
  coins: number;
  gems: number;
  items: {
    [itemId: string]: {
      quantity: number;
      purchasedAt: string;
    };
  };
}

interface Transaction {
  id: string;
  userId: string;
  type: "purchase" | "sale" | "reward";
  itemId?: string;
  quantity: number;
  amount: number;
  currency: "coins" | "gems";
  timestamp: string;
}

export const handler = async (
  event: APIGatewayProxyEvent,
): Promise<APIGatewayProxyResult> => {
  try {
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
    const { action } = body;

    switch (action) {
      case "getItems":
        return await getShopItems();
      case "purchase":
        return await purchaseItem(userId, body.itemId, body.quantity || 1);
      case "inventory":
        return await getUserInventory(userId);
      case "sell":
        return await sellItem(
          userId,
          body.itemId,
          body.quantity || 1,
          body.price,
        );
      case "getTransactions":
        return await getTransactionHistory(userId);
      case "validateEconomy":
        return await validatePlayerEconomy(userId);
      case "getPricing":
        return await getDynamicPricing();
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
  } catch (error) {
    console.error("Shop handler error:", error);
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

async function getShopItems(): Promise<APIGatewayProxyResult> {
  const cacheKey = "shop:items";

  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: cached,
      };
    }
  } catch (error) {
    console.warn("Redis cache miss:", error);
  }

  const items: ShopItem[] = [
    {
      id: "hint_basic",
      name: "Basic Hint",
      description: "Reveals one incorrect answer",
      price: 50,
      currency: "coins",
      category: "powerup",
      icon: "lightbulb",
      rarity: "common",
      effects: [{ type: "hint", value: 1 }],
    },
    {
      id: "hint_advanced",
      name: "Advanced Hint",
      description: "Reveals two incorrect answers",
      price: 100,
      currency: "coins",
      category: "powerup",
      icon: "lightbulb-on",
      rarity: "rare",
      effects: [{ type: "hint", value: 2 }],
    },
    {
      id: "time_freeze",
      name: "Time Freeze",
      description: "Stops the timer for 10 seconds",
      price: 75,
      currency: "coins",
      category: "powerup",
      icon: "clock-pause",
      rarity: "rare",
      effects: [{ type: "time_freeze", value: 10 }],
    },
    {
      id: "double_points",
      name: "Double Points",
      description: "Doubles points for the next correct answer",
      price: 25,
      currency: "gems",
      category: "booster",
      icon: "x2",
      rarity: "epic",
      effects: [{ type: "point_multiplier", value: 2 }],
    },
    {
      id: "lucky_guess",
      name: "Lucky Guess",
      description: "Automatically answers the next question correctly",
      price: 50,
      currency: "gems",
      category: "powerup",
      icon: "star",
      rarity: "legendary",
      effects: [{ type: "auto_correct", value: 1 }],
    },
    {
      id: "botanical_badge",
      name: "Botanical Expert Badge",
      description: "Show off your plant knowledge",
      price: 500,
      currency: "coins",
      category: "cosmetic",
      icon: "badge",
      rarity: "epic",
    },
  ];

  const response = {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({ items }),
  };

  try {
    await redis.setex(cacheKey, 1800, response.body);
  } catch (error) {
    console.warn("Redis cache set failed:", error);
  }

  return response;
}

async function purchaseItem(
  userId: string,
  itemId: string,
  quantity: number,
): Promise<APIGatewayProxyResult> {
  try {
    const [inventory, shopItems] = await Promise.all([
      getUserInventoryData(userId),
      getShopItemsData(),
    ]);

    const item = shopItems.find((item) => item.id === itemId);
    if (!item) {
      return {
        statusCode: 404,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({ error: "Item not found" }),
      };
    }

    const totalCost = item.price * quantity;
    const userCurrency =
      item.currency === "coins" ? inventory.coins : inventory.gems;

    if (userCurrency < totalCost) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({
          error: "Insufficient funds",
          required: totalCost,
          available: userCurrency,
        }),
      };
    }

    const transactionId = `txn_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const timestamp = new Date().toISOString();

    if (item.currency === "coins") {
      inventory.coins -= totalCost;
    } else {
      inventory.gems -= totalCost;
    }

    if (!inventory.items[itemId]) {
      inventory.items[itemId] = { quantity: 0, purchasedAt: timestamp };
    }
    inventory.items[itemId].quantity += quantity;

    const transaction: Transaction = {
      id: transactionId,
      userId,
      type: "purchase",
      itemId,
      quantity,
      amount: totalCost,
      currency: item.currency,
      timestamp,
    };

    await Promise.all([
      saveUserInventory(inventory),
      saveTransaction(transaction),
    ]);

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        success: true,
        transaction: transactionId,
        newBalance: {
          coins: inventory.coins,
          gems: inventory.gems,
        },
        item: {
          id: itemId,
          quantity: inventory.items[itemId].quantity,
        },
      }),
    };
  } catch (error) {
    console.error("Purchase error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Purchase failed" }),
    };
  }
}

async function getUserInventory(
  userId: string,
): Promise<APIGatewayProxyResult> {
  try {
    const inventory = await getUserInventoryData(userId);

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ inventory }),
    };
  } catch (error) {
    console.error("Inventory error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Failed to retrieve inventory" }),
    };
  }
}

async function sellItem(
  userId: string,
  itemId: string,
  quantity: number,
  price: number,
): Promise<APIGatewayProxyResult> {
  try {
    const inventory = await getUserInventoryData(userId);

    if (
      !inventory.items[itemId] ||
      inventory.items[itemId].quantity < quantity
    ) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({ error: "Insufficient items to sell" }),
      };
    }

    const totalEarnings = price * quantity;
    const transactionId = `txn_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const timestamp = new Date().toISOString();

    inventory.coins += totalEarnings;
    inventory.items[itemId].quantity -= quantity;

    if (inventory.items[itemId].quantity === 0) {
      delete inventory.items[itemId];
    }

    const transaction: Transaction = {
      id: transactionId,
      userId,
      type: "sale",
      itemId,
      quantity,
      amount: totalEarnings,
      currency: "coins",
      timestamp,
    };

    await Promise.all([
      saveUserInventory(inventory),
      saveTransaction(transaction),
    ]);

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        success: true,
        transaction: transactionId,
        earnings: totalEarnings,
        newBalance: {
          coins: inventory.coins,
          gems: inventory.gems,
        },
      }),
    };
  } catch (error) {
    console.error("Sell error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Sale failed" }),
    };
  }
}

async function getTransactionHistory(
  userId: string,
): Promise<APIGatewayProxyResult> {
  const cacheKey = `transactions:${userId}`;

  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: cached,
      };
    }
  } catch (error) {
    console.warn("Redis cache miss:", error);
  }

  const response = {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({ transactions: [] }),
  };

  try {
    await redis.setex(cacheKey, 300, response.body);
  } catch (error) {
    console.warn("Redis cache set failed:", error);
  }

  return response;
}

async function getUserInventoryData(userId: string): Promise<UserInventory> {
  const cacheKey = `inventory:${userId}`;

  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
  } catch (error) {
    console.warn("Redis cache miss:", error);
  }

  try {
    const result = await dynamodb.send(
      new GetItemCommand({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { id: { S: `inventory_${userId}` } },
      }),
    );

    let inventory: UserInventory;
    if (result.Item) {
      inventory = JSON.parse(result.Item.inventoryData?.S || "{}");
    } else {
      inventory = {
        userId,
        coins: 1000,
        gems: 10,
        items: {},
      };
      await saveUserInventory(inventory);
    }

    try {
      await redis.setex(cacheKey, 600, JSON.stringify(inventory));
    } catch (error) {
      console.warn("Redis cache set failed:", error);
    }

    return inventory;
  } catch (error) {
    console.error("Error getting user inventory:", error);
    return {
      userId,
      coins: 1000,
      gems: 10,
      items: {},
    };
  }
}

async function getShopItemsData(): Promise<ShopItem[]> {
  const response = await getShopItems();
  return JSON.parse(response.body).items;
}

async function saveUserInventory(inventory: UserInventory): Promise<void> {
  await dynamodb.send(
    new PutItemCommand({
      TableName: process.env.DYNAMODB_TABLE,
      Item: {
        id: { S: `inventory_${inventory.userId}` },
        userId: { S: inventory.userId },
        inventoryData: { S: JSON.stringify(inventory) },
        ttl: {
          N: Math.floor(Date.now() / 1000 + 30 * 24 * 60 * 60).toString(),
        },
      },
    }),
  );

  try {
    await redis.setex(
      `inventory:${inventory.userId}`,
      600,
      JSON.stringify(inventory),
    );
  } catch (error) {
    console.warn("Redis cache set failed:", error);
  }
}

async function saveTransaction(transaction: Transaction): Promise<void> {
  await dynamodb.send(
    new PutItemCommand({
      TableName: process.env.DYNAMODB_TABLE,
      Item: {
        id: { S: transaction.id },
        userId: { S: transaction.userId },
        transactionData: { S: JSON.stringify(transaction) },
        ttl: {
          N: Math.floor(Date.now() / 1000 + 90 * 24 * 60 * 60).toString(),
        },
      },
    }),
  );
}

async function validatePlayerEconomy(
  userId: string,
): Promise<APIGatewayProxyResult> {
  try {
    const inventory = await getUserInventoryData(userId);
    
    const mockPlayerStats = {
      gamesPlayed: 50,
      gamesWon: 30,
    };

    const validation = economyBalancer.validatePlayerEconomy(
      inventory.coins,
      inventory.gems,
      mockPlayerStats.gamesPlayed,
      mockPlayerStats.gamesWon,
    );

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        validation,
        currentBalance: {
          coins: inventory.coins,
          gems: inventory.gems,
        },
      }),
    };
  } catch (error) {
    console.error("Economy validation error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Validation failed" }),
    };
  }
}

async function getDynamicPricing(): Promise<APIGatewayProxyResult> {
  try {
    const baseItems = await getShopItemsData();
    const itemsWithDynamicPricing = baseItems.map((item) => {
      const mockPurchaseVolume = Math.floor(Math.random() * 200);
      const adjustedPrice = economyBalancer.adjustDynamicPricing(
        item.id,
        item.price,
        mockPurchaseVolume,
        24,
      );

      return {
        ...item,
        originalPrice: item.price,
        currentPrice: adjustedPrice,
        demandLevel: mockPurchaseVolume > 150 ? "high" : mockPurchaseVolume > 75 ? "medium" : "low",
      };
    });

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({
        items: itemsWithDynamicPricing,
        priceUpdateTime: new Date().toISOString(),
      }),
    };
  } catch (error) {
    console.error("Dynamic pricing error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Failed to get pricing" }),
    };
  }
}
