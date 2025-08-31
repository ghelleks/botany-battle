import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import sharp from "sharp";

const s3 = new S3Client({ region: process.env.REGION });

export interface ImageProcessingOptions {
  width?: number;
  height?: number;
  quality?: number;
  format?: "jpeg" | "png" | "webp";
}

export interface ProcessedImage {
  url: string;
  width: number;
  height: number;
  size: number;
  format: string;
}

export class ImageProcessor {
  private readonly bucketName: string;
  private readonly cacheDuration: number;

  constructor(bucketName: string, cacheDuration: number = 3600) {
    this.bucketName = bucketName;
    this.cacheDuration = cacheDuration;
  }

  async processAndUploadImage(
    sourceKey: string,
    targetKey: string,
    options: ImageProcessingOptions = {},
  ): Promise<ProcessedImage> {
    try {
      const sourceExists = await this.checkImageExists(sourceKey);
      if (!sourceExists) {
        throw new Error(`Source image not found: ${sourceKey}`);
      }

      const processedExists = await this.checkImageExists(targetKey);
      if (processedExists) {
        return this.getImageMetadata(targetKey);
      }

      const sourceBuffer = await this.downloadImage(sourceKey);
      const processedBuffer = await this.processImage(sourceBuffer, options);

      await this.uploadImage(
        targetKey,
        processedBuffer,
        options.format || "jpeg",
      );

      return this.getImageMetadata(targetKey);
    } catch (error) {
      console.error("Error processing image:", error);
      throw error;
    }
  }

  async processImage(
    imageBuffer: Buffer,
    options: ImageProcessingOptions = {},
  ): Promise<Buffer> {
    const {
      width = 800,
      height = 600,
      quality = 85,
      format = "jpeg",
    } = options;

    let sharpInstance = sharp(imageBuffer);

    if (width || height) {
      sharpInstance = sharpInstance.resize(width, height, {
        fit: "cover",
        position: "center",
      });
    }

    switch (format) {
      case "jpeg":
        sharpInstance = sharpInstance.jpeg({ quality, progressive: true });
        break;
      case "png":
        sharpInstance = sharpInstance.png({ compressionLevel: 9 });
        break;
      case "webp":
        sharpInstance = sharpInstance.webp({ quality });
        break;
    }

    return sharpInstance.toBuffer();
  }

  async getOptimizedImageUrl(
    plantId: string,
    size: "thumbnail" | "medium" | "large" = "medium",
  ): Promise<string> {
    const sizeOptions = {
      thumbnail: { width: 200, height: 150, quality: 70 },
      medium: { width: 800, height: 600, quality: 85 },
      large: { width: 1200, height: 900, quality: 90 },
    };

    const options = sizeOptions[size];
    const sourceKey = `plants/original/${plantId}.jpg`;
    const targetKey = `plants/${size}/${plantId}.jpg`;

    try {
      const processedImage = await this.processAndUploadImage(
        sourceKey,
        targetKey,
        options,
      );
      return processedImage.url;
    } catch (error) {
      console.warn(`Failed to process image for ${plantId}, using placeholder`);
      return this.getPlaceholderUrl(plantId, size);
    }
  }

  async downloadImage(key: string): Promise<Buffer> {
    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    const response = await s3.send(command);
    if (!response.Body) {
      throw new Error("Empty response body");
    }

    const stream = response.Body as NodeJS.ReadableStream;
    const chunks: Buffer[] = [];

    return new Promise((resolve, reject) => {
      stream.on("data", (chunk) => chunks.push(chunk));
      stream.on("error", reject);
      stream.on("end", () => resolve(Buffer.concat(chunks)));
    });
  }

  async uploadImage(
    key: string,
    buffer: Buffer,
    format: string,
  ): Promise<void> {
    const contentType = `image/${format}`;

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      Body: buffer,
      ContentType: contentType,
      CacheControl: `max-age=${this.cacheDuration}`,
      Metadata: {
        processedAt: new Date().toISOString(),
      },
    });

    await s3.send(command);
  }

  async checkImageExists(key: string): Promise<boolean> {
    try {
      await s3.send(
        new HeadObjectCommand({
          Bucket: this.bucketName,
          Key: key,
        }),
      );
      return true;
    } catch (error) {
      return false;
    }
  }

  async getImageMetadata(key: string): Promise<ProcessedImage> {
    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    const signedUrl = await getSignedUrl(s3, command, {
      expiresIn: this.cacheDuration,
    });

    const headCommand = new HeadObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    const metadata = await s3.send(headCommand);

    return {
      url: signedUrl,
      width: parseInt(metadata.Metadata?.width || "0"),
      height: parseInt(metadata.Metadata?.height || "0"),
      size: metadata.ContentLength || 0,
      format: metadata.ContentType?.split("/")[1] || "jpeg",
    };
  }

  private getPlaceholderUrl(plantId: string, size: string): string {
    const dimensions = {
      thumbnail: "200x150",
      medium: "800x600",
      large: "1200x900",
    };

    const dimension = dimensions[size as keyof typeof dimensions] || "800x600";
    return `https://via.placeholder.com/${dimension}?text=${encodeURIComponent(
      plantId,
    )}`;
  }

  async generateMultipleSizes(
    plantId: string,
    sourceKey: string,
  ): Promise<{ [key: string]: ProcessedImage }> {
    const sizes = ["thumbnail", "medium", "large"] as const;
    const results: { [key: string]: ProcessedImage } = {};

    for (const size of sizes) {
      try {
        const url = await this.getOptimizedImageUrl(plantId, size);
        const targetKey = `plants/${size}/${plantId}.jpg`;
        results[size] = await this.getImageMetadata(targetKey);
      } catch (error) {
        console.warn(`Failed to generate ${size} for ${plantId}:`, error);
        results[size] = {
          url: this.getPlaceholderUrl(plantId, size),
          width: 0,
          height: 0,
          size: 0,
          format: "jpeg",
        };
      }
    }

    return results;
  }

  async batchProcessImages(
    imageRequests: Array<{
      plantId: string;
      sourceKey: string;
      sizes: Array<"thumbnail" | "medium" | "large">;
    }>,
  ): Promise<{ [plantId: string]: { [size: string]: ProcessedImage } }> {
    const results: { [plantId: string]: { [size: string]: ProcessedImage } } =
      {};

    const promises = imageRequests.map(
      async ({ plantId, sourceKey, sizes }) => {
        const sizeResults: { [size: string]: ProcessedImage } = {};

        for (const size of sizes) {
          try {
            const url = await this.getOptimizedImageUrl(plantId, size);
            const targetKey = `plants/${size}/${plantId}.jpg`;
            sizeResults[size] = await this.getImageMetadata(targetKey);
          } catch (error) {
            console.warn(`Batch process failed for ${plantId}:${size}`, error);
            sizeResults[size] = {
              url: this.getPlaceholderUrl(plantId, size),
              width: 0,
              height: 0,
              size: 0,
              format: "jpeg",
            };
          }
        }

        results[plantId] = sizeResults;
      },
    );

    await Promise.all(promises);
    return results;
  }
}

export const createImageProcessor = (
  bucketName?: string,
  cacheDuration?: number,
): ImageProcessor => {
  return new ImageProcessor(
    bucketName || process.env.S3_BUCKET || "",
    cacheDuration,
  );
};
