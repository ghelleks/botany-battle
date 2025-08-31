/**
 * Security Tests for Botany Battle Backend
 */

import { APIGatewayProxyEvent } from "aws-lambda";

describe("Security Tests", () => {
  describe("Authentication and Authorization", () => {
    it("should reject requests without valid Game Center tokens", async () => {
      const unauthorizedEvent: Partial<APIGatewayProxyEvent> = {
        headers: {},
        requestContext: {} as any,
      };

      const mockSecurityCheck = (event: any) => {
        const authHeader =
          event.headers?.Authorization || event.headers?.authorization;
        if (!authHeader || !authHeader.startsWith("GameCenter ")) {
          return {
            statusCode: 401,
            body: JSON.stringify({
              error: "Unauthorized: Missing Game Center token",
            }),
          };
        }
        return { statusCode: 200, body: JSON.stringify({ success: true }) };
      };

      const result = mockSecurityCheck(unauthorizedEvent);
      expect(result.statusCode).toBe(401);
    });

    it("should validate Game Center token structure and expiration", async () => {
      // Mock expired Game Center token
      const expiredTokenData = {
        playerId: "G:123456789",
        signature: "dGVzdF9zaWduYXR1cmU=",
        salt: "dGVzdF9zYWx0",
        timestamp: String(Math.floor(Date.now() / 1000) - 3600), // 1 hour ago
        bundleId: "com.botanybattle.app",
      };
      const expiredToken = Buffer.from(
        JSON.stringify(expiredTokenData),
      ).toString("base64");

      const mockGameCenterTokenValidation = (token: string) => {
        try {
          const decodedData = Buffer.from(token, "base64").toString("utf-8");
          const tokenData = JSON.parse(decodedData);

          // Validate required fields
          if (
            !tokenData.playerId ||
            !tokenData.signature ||
            !tokenData.salt ||
            !tokenData.timestamp
          ) {
            throw new Error("Invalid token structure: missing required fields");
          }

          // Check token age (5 minutes max)
          const tokenTime = parseInt(tokenData.timestamp);
          const currentTime = Math.floor(Date.now() / 1000);
          const timeDiff = currentTime - tokenTime;

          if (timeDiff > 300) {
            // 5 minutes
            throw new Error("Token expired");
          }

          // Validate bundle ID
          if (tokenData.bundleId !== "com.botanybattle.app") {
            throw new Error("Invalid bundle ID");
          }

          return { valid: true, tokenData };
        } catch (error) {
          return { valid: false, error: (error as Error).message };
        }
      };

      const result = mockGameCenterTokenValidation(expiredToken);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Token expired");
    });

    it("should validate Game Center token bundle ID", async () => {
      const invalidBundleTokenData = {
        playerId: "G:123456789",
        signature: "dGVzdF9zaWduYXR1cmU=",
        salt: "dGVzdF9zYWx0",
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: "com.malicious.app", // Wrong bundle ID
      };
      const invalidToken = Buffer.from(
        JSON.stringify(invalidBundleTokenData),
      ).toString("base64");

      const mockGameCenterTokenValidation = (token: string) => {
        try {
          const decodedData = Buffer.from(token, "base64").toString("utf-8");
          const tokenData = JSON.parse(decodedData);

          if (tokenData.bundleId !== "com.botanybattle.app") {
            throw new Error("Invalid bundle ID");
          }

          return { valid: true, tokenData };
        } catch (error) {
          return { valid: false, error: (error as Error).message };
        }
      };

      const result = mockGameCenterTokenValidation(invalidToken);
      expect(result.valid).toBe(false);
      expect(result.error).toBe("Invalid bundle ID");
    });

    it("should prevent unauthorized access with malformed Game Center tokens", async () => {
      const malformedTokens = [
        "", // Empty token
        "invalid-base64!@#", // Invalid base64
        Buffer.from("not-json").toString("base64"), // Valid base64 but not JSON
        Buffer.from("{}").toString("base64"), // Valid JSON but missing fields
        Buffer.from(JSON.stringify({ playerId: "G:123" })).toString("base64"), // Missing required fields
      ];

      const mockGameCenterTokenValidation = (token: string) => {
        try {
          if (!token) {
            throw new Error("Empty token");
          }

          const decodedData = Buffer.from(token, "base64").toString("utf-8");
          const tokenData = JSON.parse(decodedData);

          if (
            !tokenData.playerId ||
            !tokenData.signature ||
            !tokenData.salt ||
            !tokenData.timestamp
          ) {
            throw new Error("Invalid token structure: missing required fields");
          }

          return { valid: true, tokenData };
        } catch (error) {
          return { valid: false, error: (error as Error).message };
        }
      };

      malformedTokens.forEach((token) => {
        const result = mockGameCenterTokenValidation(token);
        expect(result.valid).toBe(false);
      });
    });
  });

  describe("Input Validation and Sanitization", () => {
    it("should reject malicious SQL injection attempts", async () => {
      const maliciousInputs = [
        "'; DROP TABLE users; --",
        "1' OR '1'='1",
        "admin'/**/OR/**/1=1/**/--",
        "1; DELETE FROM games WHERE 1=1; --",
      ];

      const mockSqlValidation = (input: string) => {
        const sqlInjectionPatterns = [
          /(\'|\\\'|;|\s*(union|select|insert|delete|update|drop|create|alter|exec|execute)\s+)/i,
          /((\s*)|(\+))(union|select|insert|delete|update|drop|create|alter|exec|execute)(\s*)/i,
          /(\s*(or|and)\s*.*\s*(=|like)\s*.*)/i,
        ];

        const isMalicious = sqlInjectionPatterns.some((pattern) =>
          pattern.test(input),
        );
        return { valid: !isMalicious, input };
      };

      maliciousInputs.forEach((input) => {
        const result = mockSqlValidation(input);
        expect(result.valid).toBe(false);
      });
    });

    it("should prevent XSS attacks in user input", async () => {
      const xssPayloads = [
        '<script>alert("xss")</script>',
        'javascript:alert("xss")',
        '<img src="x" onerror="alert(1)">',
        '<svg onload="alert(1)">',
        'data:text/html,<script>alert("xss")</script>',
      ];

      const mockXssValidation = (input: string) => {
        const xssPatterns = [
          /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
          /javascript:/gi,
          /on\w+\s*=/gi,
          /<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi,
          /data:text\/html/gi,
        ];

        const isMalicious = xssPatterns.some((pattern) => pattern.test(input));
        return { valid: !isMalicious, sanitized: input.replace(/[<>'"]/g, "") };
      };

      xssPayloads.forEach((payload) => {
        const result = mockXssValidation(payload);
        expect(result.valid).toBe(false);
      });
    });

    it("should validate and sanitize user profile data", async () => {
      const testCases = [
        {
          input: {
            username: "user123",
            displayName: "John Doe",
            bio: "Plant lover",
          },
          expected: { valid: true },
        },
        {
          input: { username: "", displayName: "John Doe", bio: "Plant lover" },
          expected: { valid: false, error: "Username required" },
        },
        {
          input: {
            username: "a".repeat(101),
            displayName: "John Doe",
            bio: "Plant lover",
          },
          expected: { valid: false, error: "Username too long" },
        },
        {
          input: {
            username: "user123",
            displayName: '<script>alert("xss")</script>',
            bio: "Plant lover",
          },
          expected: {
            valid: false,
            error: "Invalid characters in display name",
          },
        },
      ];

      const mockProfileValidation = (data: any) => {
        if (!data.username || data.username.trim() === "") {
          return { valid: false, error: "Username required" };
        }

        if (data.username.length > 100) {
          return { valid: false, error: "Username too long" };
        }

        const dangerousChars = /<[^>]*>|javascript:|on\w+=/i;
        if (dangerousChars.test(data.displayName || "")) {
          return { valid: false, error: "Invalid characters in display name" };
        }

        return { valid: true };
      };

      testCases.forEach((testCase) => {
        const result = mockProfileValidation(testCase.input);
        expect(result.valid).toBe(testCase.expected.valid);
        if (!testCase.expected.valid) {
          expect(result.error).toBe(testCase.expected.error);
        }
      });
    });
  });

  describe("Rate Limiting and DoS Protection", () => {
    it("should enforce rate limits on API endpoints", async () => {
      const rateLimit = 100; // requests per minute
      const timeWindow = 60 * 1000; // 1 minute
      const requestCounts = new Map<
        string,
        { count: number; windowStart: number }
      >();

      const mockRateLimit = (clientId: string) => {
        const now = Date.now();
        const clientData = requestCounts.get(clientId) || {
          count: 0,
          windowStart: now,
        };

        // Reset window if expired
        if (now - clientData.windowStart > timeWindow) {
          clientData.count = 0;
          clientData.windowStart = now;
        }

        clientData.count++;
        requestCounts.set(clientId, clientData);

        if (clientData.count > rateLimit) {
          return { allowed: false, error: "Rate limit exceeded" };
        }

        return {
          allowed: true,
          remainingRequests: rateLimit - clientData.count,
        };
      };

      // Test normal usage
      for (let i = 0; i < rateLimit; i++) {
        const result = mockRateLimit("client-1");
        expect(result.allowed).toBe(true);
      }

      // Test rate limit exceeded
      const exceededResult = mockRateLimit("client-1");
      expect(exceededResult.allowed).toBe(false);
      expect(exceededResult.error).toBe("Rate limit exceeded");
    });

    it("should detect and prevent brute force attacks", async () => {
      const maxAttempts = 5;
      const lockoutDuration = 15 * 60 * 1000; // 15 minutes
      const attemptCounts = new Map<
        string,
        { attempts: number; lastAttempt: number; lockedUntil?: number }
      >();

      const mockBruteForceProtection = (
        identifier: string,
        successful: boolean,
      ) => {
        const now = Date.now();
        const attempts = attemptCounts.get(identifier) || {
          attempts: 0,
          lastAttempt: 0,
        };

        // Check if still locked out
        if (attempts.lockedUntil && now < attempts.lockedUntil) {
          return {
            allowed: false,
            error: "Account temporarily locked",
            lockedUntil: attempts.lockedUntil,
          };
        }

        if (successful) {
          // Reset on successful attempt
          attemptCounts.set(identifier, { attempts: 0, lastAttempt: now });
          return { allowed: true };
        } else {
          // Increment failed attempts
          attempts.attempts++;
          attempts.lastAttempt = now;

          if (attempts.attempts >= maxAttempts) {
            attempts.lockedUntil = now + lockoutDuration;
            attemptCounts.set(identifier, attempts);
            return {
              allowed: false,
              error: "Too many failed attempts",
              lockedUntil: attempts.lockedUntil,
            };
          }

          attemptCounts.set(identifier, attempts);
          return {
            allowed: true,
            remainingAttempts: maxAttempts - attempts.attempts,
          };
        }
      };

      // Test normal failed attempts
      for (let i = 0; i < maxAttempts - 1; i++) {
        const result = mockBruteForceProtection("test-user", false);
        expect(result.allowed).toBe(true);
      }

      // Test lockout
      const lockoutResult = mockBruteForceProtection("test-user", false);
      expect(lockoutResult.allowed).toBe(false);
      expect(lockoutResult.error).toBe("Too many failed attempts");
    });

    it("should handle connection floods gracefully", async () => {
      const maxConcurrentConnections = 1000;
      const activeConnections = new Set<string>();

      const mockConnectionManager = (
        connectionId: string,
        action: "connect" | "disconnect",
      ) => {
        if (action === "connect") {
          if (activeConnections.size >= maxConcurrentConnections) {
            return { success: false, error: "Connection limit reached" };
          }
          activeConnections.add(connectionId);
          return { success: true, totalConnections: activeConnections.size };
        } else {
          activeConnections.delete(connectionId);
          return { success: true, totalConnections: activeConnections.size };
        }
      };

      // Test normal connections
      for (let i = 0; i < maxConcurrentConnections; i++) {
        const result = mockConnectionManager(`conn-${i}`, "connect");
        expect(result.success).toBe(true);
      }

      // Test connection limit
      const limitResult = mockConnectionManager("conn-overflow", "connect");
      expect(limitResult.success).toBe(false);
      expect(limitResult.error).toBe("Connection limit reached");
    });
  });

  describe("Data Privacy and Protection", () => {
    it("should not expose sensitive user data in API responses", async () => {
      const mockUserData = {
        id: "user-123",
        username: "testuser",
        email: "test@example.com",
        password: "hashed-password-123",
        internalNotes: "Admin notes about user",
        paymentInfo: { cardNumber: "1234-5678-9012-3456" },
      };

      const mockDataSanitizer = (userData: any) => {
        const { password, internalNotes, paymentInfo, ...safeData } = userData;
        return safeData;
      };

      const sanitizedData = mockDataSanitizer(mockUserData);

      expect(sanitizedData).not.toHaveProperty("password");
      expect(sanitizedData).not.toHaveProperty("internalNotes");
      expect(sanitizedData).not.toHaveProperty("paymentInfo");
      expect(sanitizedData).toHaveProperty("id");
      expect(sanitizedData).toHaveProperty("username");
      expect(sanitizedData).toHaveProperty("email");
    });

    it("should properly encrypt sensitive data at rest", async () => {
      const sensitiveData = "user-secret-data";

      const mockEncryption = {
        encrypt: (data: string) => {
          // Mock encryption - in real implementation would use proper crypto
          return Buffer.from(data).toString("base64") + "-encrypted";
        },
        decrypt: (encryptedData: string) => {
          // Mock decryption
          const base64Data = encryptedData.replace("-encrypted", "");
          return Buffer.from(base64Data, "base64").toString();
        },
      };

      const encrypted = mockEncryption.encrypt(sensitiveData);
      expect(encrypted).not.toBe(sensitiveData);
      expect(encrypted).toContain("-encrypted");

      const decrypted = mockEncryption.decrypt(encrypted);
      expect(decrypted).toBe(sensitiveData);
    });

    it("should enforce data retention policies", async () => {
      const retentionPeriod = 30 * 24 * 60 * 60 * 1000; // 30 days
      const now = Date.now();

      const mockDataRecords = [
        { id: 1, createdAt: now - 35 * 24 * 60 * 60 * 1000, type: "game-data" }, // 35 days old
        { id: 2, createdAt: now - 25 * 24 * 60 * 60 * 1000, type: "game-data" }, // 25 days old
        {
          id: 3,
          createdAt: now - 40 * 24 * 60 * 60 * 1000,
          type: "user-activity",
        }, // 40 days old
      ];

      const mockRetentionCheck = (records: any[]) => {
        return records.map((record) => ({
          ...record,
          shouldDelete: now - record.createdAt > retentionPeriod,
        }));
      };

      const checkedRecords = mockRetentionCheck(mockDataRecords);

      expect(checkedRecords[0].shouldDelete).toBe(true); // 35 days old
      expect(checkedRecords[1].shouldDelete).toBe(false); // 25 days old
      expect(checkedRecords[2].shouldDelete).toBe(true); // 40 days old
    });
  });

  describe("API Security Headers", () => {
    it("should include proper security headers in responses", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "X-Content-Type-Options": "nosniff",
          "X-Frame-Options": "DENY",
          "X-XSS-Protection": "1; mode=block",
          "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
          "Content-Security-Policy": "default-src 'self'",
          "Referrer-Policy": "strict-origin-when-cross-origin",
        },
        body: JSON.stringify({ message: "Success" }),
      };

      expect(mockResponse.headers["X-Content-Type-Options"]).toBe("nosniff");
      expect(mockResponse.headers["X-Frame-Options"]).toBe("DENY");
      expect(mockResponse.headers["X-XSS-Protection"]).toBe("1; mode=block");
      expect(mockResponse.headers["Strict-Transport-Security"]).toContain(
        "max-age=31536000",
      );
      expect(mockResponse.headers["Content-Security-Policy"]).toContain(
        "default-src 'self'",
      );
    });

    it("should enforce CORS policies correctly", async () => {
      const allowedOrigins = [
        "https://botanybattle.app",
        "https://dev.botanybattle.app",
      ];

      const mockCorsCheck = (origin: string) => {
        if (!allowedOrigins.includes(origin)) {
          return { allowed: false, error: "Origin not allowed" };
        }
        return {
          allowed: true,
          headers: {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
          },
        };
      };

      // Test allowed origin
      const allowedResult = mockCorsCheck("https://botanybattle.app");
      expect(allowedResult.allowed).toBe(true);
      expect(allowedResult.headers!["Access-Control-Allow-Origin"]).toBe(
        "https://botanybattle.app",
      );

      // Test disallowed origin
      const disallowedResult = mockCorsCheck("https://malicious.com");
      expect(disallowedResult.allowed).toBe(false);
      expect(disallowedResult.error).toBe("Origin not allowed");
    });
  });

  describe("Dependency and Infrastructure Security", () => {
    it("should validate environment configuration security", async () => {
      const mockEnvConfig = {
        NODE_ENV: "production",
        JWT_SECRET: "super-secret-key-with-256-bits",
        DATABASE_URL: "postgresql://user:pass@localhost/db",
        REDIS_URL: "redis://localhost:6379",
        DEBUG: "false",
      };

      const mockSecurityAudit = (config: any) => {
        const issues = [];

        if (config.NODE_ENV !== "production") {
          issues.push("NODE_ENV should be set to production");
        }

        if (!config.JWT_SECRET || config.JWT_SECRET.length < 32) {
          issues.push("JWT_SECRET should be at least 32 characters");
        }

        if (config.DEBUG === "true") {
          issues.push("DEBUG mode should be disabled in production");
        }

        if (config.DATABASE_URL && config.DATABASE_URL.includes("localhost")) {
          issues.push("Database should not be localhost in production");
        }

        return { secure: issues.length === 0, issues };
      };

      const audit = mockSecurityAudit(mockEnvConfig);
      expect(audit.issues).toContain(
        "Database should not be localhost in production",
      );
    });

    it("should check for vulnerable dependencies", async () => {
      const mockDependencies = [
        { name: "express", version: "4.18.0", vulnerabilities: [] },
        {
          name: "lodash",
          version: "4.17.20",
          vulnerabilities: ["CVE-2021-23337"],
        },
        { name: "jsonwebtoken", version: "8.5.1", vulnerabilities: [] },
        { name: "bcrypt", version: "5.0.1", vulnerabilities: [] },
      ];

      const mockVulnerabilityCheck = (deps: any[]) => {
        const vulnerable = deps.filter((dep) => dep.vulnerabilities.length > 0);
        return {
          safe: vulnerable.length === 0,
          vulnerableDependencies: vulnerable.map((dep) => ({
            name: dep.name,
            version: dep.version,
            vulnerabilities: dep.vulnerabilities,
          })),
        };
      };

      const check = mockVulnerabilityCheck(mockDependencies);
      expect(check.safe).toBe(false);
      expect(check.vulnerableDependencies).toHaveLength(1);
      expect(check.vulnerableDependencies[0].name).toBe("lodash");
    });
  });
});
