import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

// Mock AWS SDK before importing the handler
const mockSend = jest.fn();
const mockDocClient = {
  send: mockSend
};

jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn(() => ({}))
}));

jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn(() => mockDocClient)
  },
  GetCommand: jest.fn(),
  PutCommand: jest.fn()
}));

// Import handler after mocking
import { handler } from '../authHandler';

describe('Game Center Authentication Handler', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSend.mockClear();
    process.env.DYNAMODB_TABLE = 'test-table';
    process.env.AWS_REGION = 'us-west-2';
  });

  describe('CORS Handling', () => {
    it('should handle OPTIONS requests', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'OPTIONS',
        body: null,
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(200);
      expect(result.headers).toMatchObject({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
      });
    });
  });

  describe('Method Validation', () => {
    it('should reject non-POST requests', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'GET',
        body: null,
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(405);
      expect(JSON.parse(result.body)).toEqual({ error: 'Method not allowed' });
    });
  });

  describe('Token Validation', () => {
    it('should reject requests without token', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({}),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toEqual({ error: 'Game Center token is required' });
    });

    it('should reject invalid token format', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: 'invalid-token' }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      expect(JSON.parse(result.body)).toEqual({ error: 'Invalid Game Center token' });
    });

    it('should reject expired tokens', async () => {
      const expiredTokenData = {
        playerId: 'G:123456789',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000) - 3600), // 1 hour ago
        bundleId: 'com.botanybattle.app'
      };
      const expiredToken = Buffer.from(JSON.stringify(expiredTokenData)).toString('base64');

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: expiredToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      expect(JSON.parse(result.body)).toEqual({ error: 'Invalid Game Center token' });
    });

    it('should reject tokens with wrong bundle ID', async () => {
      const invalidBundleTokenData = {
        playerId: 'G:123456789',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: 'com.malicious.app'
      };
      const invalidToken = Buffer.from(JSON.stringify(invalidBundleTokenData)).toString('base64');

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: invalidToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      expect(JSON.parse(result.body)).toEqual({ error: 'Invalid Game Center token' });
    });
  });

  describe('User Management', () => {
    it('should return existing user if found', async () => {
      const validTokenData = {
        playerId: 'G:123456789',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: 'com.botanybattle.app'
      };
      const validToken = Buffer.from(JSON.stringify(validTokenData)).toString('base64');

      const existingUser = {
        id: 'G:123456789',
        username: 'ExistingPlayer',
        displayName: 'Existing Player',
        createdAt: '2023-01-01T00:00:00.000Z',
        stats: {
          totalGamesPlayed: 10,
          totalWins: 7,
          currentStreak: 3,
          longestStreak: 5,
          eloRating: 1250,
          rank: 'Sprout',
          plantsIdentified: 25,
          accuracyRate: 0.85
        },
        currency: {
          coins: 250,
          gems: 5,
          tokens: 2
        }
      };

      mockSend.mockResolvedValueOnce({ Item: existingUser });

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: validToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(200);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.authenticated).toBe(true);
      expect(responseBody.user).toEqual(existingUser);
    });

    it('should create new user if not found', async () => {
      const validTokenData = {
        playerId: 'G:987654321',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: 'com.botanybattle.app'
      };
      const validToken = Buffer.from(JSON.stringify(validTokenData)).toString('base64');

      // Mock GetCommand returns no item (user doesn't exist)
      mockSend.mockResolvedValueOnce({ Item: null });
      // Mock PutCommand succeeds
      mockSend.mockResolvedValueOnce({});

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: validToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(200);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.authenticated).toBe(true);
      expect(responseBody.user.id).toBe('G:987654321');
      expect(responseBody.user.username).toBe('Player_87654321');
      expect(responseBody.user.stats.eloRating).toBe(1000);
      expect(responseBody.user.currency.coins).toBe(100);

      // Verify PutCommand was called to create the user
      expect(mockSend).toHaveBeenCalledTimes(2); // Get + Put
    });

    it('should handle database errors gracefully', async () => {
      const validTokenData = {
        playerId: 'G:123456789',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: 'com.botanybattle.app'
      };
      const validToken = Buffer.from(JSON.stringify(validTokenData)).toString('base64');

      mockSend.mockRejectedValueOnce(new Error('Database connection failed'));

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: validToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(500);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('Internal server error');
      expect(responseBody.message).toBe('Database connection failed');
    });
  });

  describe('Security Tests', () => {
    it('should not expose sensitive information in error messages', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: 'malformed' }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('Invalid Game Center token');
      expect(responseBody).not.toHaveProperty('stack');
      expect(responseBody).not.toHaveProperty('details');
    });

    it('should validate all required token fields', async () => {
      const incompleteTokenData = {
        playerId: 'G:123456789',
        // Missing signature, salt, timestamp, bundleId
      };
      const incompleteToken = Buffer.from(JSON.stringify(incompleteTokenData)).toString('base64');

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: incompleteToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      expect(JSON.parse(result.body)).toEqual({ error: 'Invalid Game Center token' });
    });

    it('should enforce reasonable timestamp limits', async () => {
      const futureTokenData = {
        playerId: 'G:123456789',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000) + 3600), // 1 hour in the future
        bundleId: 'com.botanybattle.app'
      };
      const futureToken = Buffer.from(JSON.stringify(futureTokenData)).toString('base64');

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: futureToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(401);
      expect(JSON.parse(result.body)).toEqual({ error: 'Invalid Game Center token' });
    });
  });

  describe('Performance Tests', () => {
    it('should handle concurrent authentication requests', async () => {
      const validTokenData = {
        playerId: 'G:concurrent-test',
        signature: 'dGVzdF9zaWduYXR1cmU=',
        salt: 'dGVzdF9zYWx0',
        timestamp: String(Math.floor(Date.now() / 1000)),
        bundleId: 'com.botanybattle.app'
      };
      const validToken = Buffer.from(JSON.stringify(validTokenData)).toString('base64');

      mockSend.mockResolvedValue({ Item: null }); // User doesn't exist
      mockSend.mockResolvedValue({}); // Put succeeds

      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: JSON.stringify({ token: validToken }),
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      // Simulate concurrent requests
      const promises = Array(10).fill(null).map(() => handler(event));
      const results = await Promise.all(promises);

      // All requests should succeed
      results.forEach(result => {
        expect(result.statusCode).toBe(200);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle malformed JSON in request body', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: '{ invalid json }',
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(500);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('Internal server error');
    });

    it('should handle null request body', async () => {
      const event: APIGatewayProxyEvent = {
        httpMethod: 'POST',
        body: null,
        headers: {},
        isBase64Encoded: false,
        path: '/auth/gamecenter',
        pathParameters: null,
        queryStringParameters: null,
        requestContext: {} as any,
        resource: '',
        stageVariables: null,
        multiValueHeaders: {},
        multiValueQueryStringParameters: null
      };

      const result: APIGatewayProxyResult = await handler(event);

      expect(result.statusCode).toBe(400);
      expect(JSON.parse(result.body)).toEqual({ error: 'Game Center token is required' });
    });
  });
});