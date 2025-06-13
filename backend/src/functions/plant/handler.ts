import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
} from "@aws-sdk/client-dynamodb";
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import Redis from "ioredis";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { createImageProcessor } from "../../utils/imageProcessor";

const dynamodb = new DynamoDBClient({ region: process.env.REGION });
const s3 = new S3Client({ region: process.env.REGION });
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: parseInt(process.env.REDIS_PORT || "6379"),
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
});
const imageProcessor = createImageProcessor();

interface Plant {
  id: string;
  scientificName: string;
  commonName: string;
  family: string;
  imageUrl: string;
  difficulty: "easy" | "medium" | "hard";
  description: string;
  habitat: string;
  distribution: string;
  tags: string[];
}

interface PlantQuestion {
  plantId: string;
  question: string;
  options: string[];
  correctAnswer: string;
  difficulty: string;
  imageUrl: string;
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

    const queryParams = event.queryStringParameters || {};
    const {
      action = "getQuestion",
      difficulty = "medium",
      count = "1",
    } = queryParams;

    switch (action) {
      case "getQuestion":
        return await getPlantQuestion(difficulty, parseInt(count));
      case "getPlant":
        return await getPlantDetails(queryParams.plantId!);
      case "searchPlants":
        return await searchPlants(queryParams.query || "", difficulty);
      case "getRandomPlants":
        return await getRandomPlants(parseInt(count));
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
    console.error("Plant handler error:", error);
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

async function getPlantQuestion(
  difficulty: string,
  count: number,
): Promise<APIGatewayProxyResult> {
  const cacheKey = `questions:${difficulty}:${count}`;

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

  const questions = await generatePlantQuestions(difficulty, count);

  const response = {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({ questions }),
  };

  try {
    await redis.setex(cacheKey, 300, response.body);
  } catch (error) {
    console.warn("Redis cache set failed:", error);
  }

  return response;
}

async function generatePlantQuestions(
  difficulty: string,
  count: number,
): Promise<PlantQuestion[]> {
  const plants = await getPlantsByDifficulty(difficulty, count * 4);
  const questions: PlantQuestion[] = [];

  for (let i = 0; i < Math.min(count, plants.length); i++) {
    const correctPlant = plants[i];
    const wrongOptions = plants.slice(i + 1, i + 4).map((p) => p.commonName);

    while (wrongOptions.length < 3) {
      const randomPlant = plants[Math.floor(Math.random() * plants.length)];
      if (
        randomPlant.id !== correctPlant.id &&
        !wrongOptions.includes(randomPlant.commonName)
      ) {
        wrongOptions.push(randomPlant.commonName);
      }
    }

    const options = [correctPlant.commonName, ...wrongOptions.slice(0, 3)];

    for (let j = options.length - 1; j > 0; j--) {
      const k = Math.floor(Math.random() * (j + 1));
      [options[j], options[k]] = [options[k], options[j]];
    }

    questions.push({
      plantId: correctPlant.id,
      question: `What is the common name of this plant?`,
      options,
      correctAnswer: correctPlant.commonName,
      difficulty,
      imageUrl: await imageProcessor.getOptimizedImageUrl(correctPlant.id, "medium"),
    });
  }

  return questions;
}

async function getPlantsByDifficulty(
  difficulty: string,
  limit: number,
): Promise<Plant[]> {
  const mockPlants: Plant[] = [
    {
      id: "plant_001",
      scientificName: "Rosa rubiginosa",
      commonName: "Sweet Briar",
      family: "Rosaceae",
      imageUrl: "plants/rosa_rubiginosa.jpg",
      difficulty: "easy",
      description: "A climbing rose with fragrant foliage",
      habitat: "Woodland edges and hedgerows",
      distribution: "Europe and western Asia",
      tags: ["flowering", "climbing", "fragrant"],
    },
    {
      id: "plant_002",
      scientificName: "Quercus robur",
      commonName: "English Oak",
      family: "Fagaceae",
      imageUrl: "plants/quercus_robur.jpg",
      difficulty: "easy",
      description: "A large deciduous tree with distinctive lobed leaves",
      habitat: "Mixed woodlands and parklands",
      distribution: "Europe and parts of Asia",
      tags: ["tree", "deciduous", "acorns"],
    },
    {
      id: "plant_003",
      scientificName: "Digitalis purpurea",
      commonName: "Foxglove",
      family: "Plantaginaceae",
      imageUrl: "plants/digitalis_purpurea.jpg",
      difficulty: "medium",
      description: "Tall spikes of tubular purple flowers",
      habitat: "Woodland clearings and hillsides",
      distribution: "Western and southwestern Europe",
      tags: ["flowering", "poisonous", "medicinal"],
    },
    {
      id: "plant_004",
      scientificName: "Orchis mascula",
      commonName: "Early Purple Orchid",
      family: "Orchidaceae",
      imageUrl: "plants/orchis_mascula.jpg",
      difficulty: "hard",
      description: "A terrestrial orchid with spotted leaves",
      habitat: "grasslands and open woodlands",
      distribution: "Europe and parts of Asia",
      tags: ["orchid", "flowering", "rare"],
    },
  ];

  const filteredPlants =
    difficulty === "all"
      ? mockPlants
      : mockPlants.filter((plant) => plant.difficulty === difficulty);

  return filteredPlants.slice(0, limit);
}

async function getPlantDetails(
  plantId: string,
): Promise<APIGatewayProxyResult> {
  const cacheKey = `plant:${plantId}`;

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

  try {
    const result = await dynamodb.send(
      new GetItemCommand({
        TableName: process.env.DYNAMODB_TABLE,
        Key: { id: { S: plantId } },
      }),
    );

    let plant: Plant | null = null;
    if (result.Item) {
      plant = JSON.parse(result.Item.plantData?.S || "{}");
    } else {
      const mockPlants = await getPlantsByDifficulty("all", 100);
      plant = mockPlants.find((p) => p.id === plantId) || null;
    }

    if (!plant) {
      return {
        statusCode: 404,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: JSON.stringify({ error: "Plant not found" }),
      };
    }

    plant.imageUrl = await imageProcessor.getOptimizedImageUrl(plantId, "large");

    const response = {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ plant }),
    };

    try {
      await redis.setex(cacheKey, 3600, response.body);
    } catch (error) {
      console.warn("Redis cache set failed:", error);
    }

    return response;
  } catch (error) {
    console.error("Error getting plant details:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      body: JSON.stringify({ error: "Failed to retrieve plant details" }),
    };
  }
}

async function searchPlants(
  query: string,
  difficulty: string,
): Promise<APIGatewayProxyResult> {
  const cacheKey = `search:${query}:${difficulty}`;

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

  const allPlants = await getPlantsByDifficulty(difficulty, 100);
  const filteredPlants = allPlants.filter(
    (plant) =>
      plant.commonName.toLowerCase().includes(query.toLowerCase()) ||
      plant.scientificName.toLowerCase().includes(query.toLowerCase()) ||
      plant.family.toLowerCase().includes(query.toLowerCase()) ||
      plant.tags.some((tag) => tag.toLowerCase().includes(query.toLowerCase())),
  );

  const response = {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({
      plants: filteredPlants,
      total: filteredPlants.length,
    }),
  };

  try {
    await redis.setex(cacheKey, 600, response.body);
  } catch (error) {
    console.warn("Redis cache set failed:", error);
  }

  return response;
}

async function getRandomPlants(count: number): Promise<APIGatewayProxyResult> {
  const allPlants = await getPlantsByDifficulty("all", 100);
  const shuffled = [...allPlants].sort(() => 0.5 - Math.random());
  const selectedPlants = shuffled.slice(0, count);

  for (const plant of selectedPlants) {
    plant.imageUrl = await imageProcessor.getOptimizedImageUrl(plant.id, "medium");
  }

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({ plants: selectedPlants }),
  };
}

async function getPlantImageUrl(plantId: string): Promise<string> {
  try {
    const command = new GetObjectCommand({
      Bucket: process.env.S3_BUCKET,
      Key: `plants/${plantId}.jpg`,
    });

    return await getSignedUrl(s3, command, { expiresIn: 3600 });
  } catch (error) {
    console.warn(`No image found for plant ${plantId}, using placeholder`);
    return `https://via.placeholder.com/400x300?text=${plantId}`;
  }
}
