import {
  getUserProfile,
  updateUserProfile,
  getLeaderboard,
  getUserStats,
  updateUserELO
} from '../handler';

// Mock AWS SDK
jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn(() => ({
      send: jest.fn()
    }))
  },
  GetCommand: jest.fn(),
  UpdateCommand: jest.fn(),
  QueryCommand: jest.fn()
}));

// Mock Redis
jest.mock('redis', () => ({
  createClient: jest.fn(() => ({
    connect: jest.fn(),
    get: jest.fn(),
    setEx: jest.fn(),
    keys: jest.fn(),
    del: jest.fn()
  }))
}));

// Mock ELO ranking functions
jest.mock('../game/eloRanking', () => ({
  getRankFromRating: jest.fn((rating) => {
    if (rating >= 1200) return 'Green Thumb';
    if (rating >= 1000) return 'Sprout';
    return 'Seedling';
  }),
  calculateLeaderboardStats: jest.fn((rating, wins, losses, streak) => ({
    eloRating: rating,
    rankTitle: rating >= 1200 ? 'Green Thumb' : 'Sprout',
    totalWins: wins,
    totalGamesPlayed: wins + losses,
    winRate: wins + losses > 0 ? (wins / (wins + losses)) * 100 : 0,
    currentStreak: streak
  }))
}));

describe('User Service', () => {
  let mockDynamoDb: any;
  let mockRedis: any;
  let mockEvent: any;

  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup DynamoDB mock
    const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
    mockDynamoDb = DynamoDBDocumentClient.from();
    
    // Setup Redis mock
    const { createClient } = require('redis');
    mockRedis = createClient();
    
    // Setup mock API Gateway event
    mockEvent = {
      requestContext: {
        authorizer: {
          claims: {
            sub: 'test-user-id'
          }
        }
      },
      body: null,
      queryStringParameters: null
    };
  });

  describe('getUserProfile', () => {
    const mockUserProfile = {
      userId: 'test-user-id',
      username: 'testuser',
      email: 'test@example.com',
      displayName: 'Test User',
      avatarURL: 'https://example.com/avatar.jpg',
      createdAt: '2023-01-01T00:00:00Z'
    };

    const mockUserStats = {
      userId: 'test-user-id',
      eloRating: 1250,
      rank: 'Green Thumb',
      totalGamesPlayed: 25,
      totalWins: 18,
      currentStreak: 3,
      longestStreak: 7,
      plantsIdentified: 45,
      accuracyRate: 0.82
    };

    it('should return user profile with stats', async () => {
      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: mockUserProfile }) // Profile query
        .mockResolvedValueOnce({ Item: mockUserStats }); // Stats query

      const result = await getUserProfile(mockEvent);

      expect(result.statusCode).toBe(200);
      
      const responseBody = JSON.parse(result.body);
      expect(responseBody.user).toEqual({
        id: 'test-user-id',
        username: 'testuser',
        email: 'test@example.com',
        displayName: 'Test User',
        avatarURL: 'https://example.com/avatar.jpg',
        createdAt: '2023-01-01T00:00:00Z',
        stats: {
          totalGamesPlayed: 25,
          totalWins: 18,
          currentStreak: 3,
          longestStreak: 7,
          eloRating: 1250,
          rank: 'Green Thumb',
          plantsIdentified: 45,
          accuracyRate: 0.82
        },
        currency: {
          coins: 100,
          gems: 0,
          tokens: 0
        }
      });
    });

    it('should initialize stats for new user', async () => {
      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: mockUserProfile }) // Profile query
        .mockResolvedValueOnce({}); // No stats found

      const result = await getUserProfile(mockEvent);

      expect(result.statusCode).toBe(200);
      expect(mockDynamoDb.send).toHaveBeenCalledTimes(3); // Profile + Stats + Initialize stats
    });

    it('should return 404 for non-existent user', async () => {
      mockDynamoDb.send.mockResolvedValueOnce({}); // No profile found

      const result = await getUserProfile(mockEvent);

      expect(result.statusCode).toBe(404);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('User not found');
    });

    it('should return 401 for unauthorized request', async () => {
      const unauthorizedEvent = {
        ...mockEvent,
        requestContext: {}
      };

      const result = await getUserProfile(unauthorizedEvent);

      expect(result.statusCode).toBe(401);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('Unauthorized');
    });

    it('should handle database errors', async () => {
      mockDynamoDb.send.mockRejectedValue(new Error('Database error'));

      const result = await getUserProfile(mockEvent);

      expect(result.statusCode).toBe(500);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.error).toBe('Internal server error');
    });
  });

  describe('updateUserProfile', () => {
    it('should update user profile successfully', async () => {
      const updateEvent = {
        ...mockEvent,
        body: JSON.stringify({
          displayName: 'Updated Name',
          bio: 'Updated bio',
          isPrivate: true
        })
      };

      // Mock successful update and profile retrieval
      mockDynamoDb.send
        .mockResolvedValueOnce({}) // Update operation
        .mockResolvedValueOnce({ // Profile retrieval
          Item: {
            userId: 'test-user-id',
            username: 'testuser',
            displayName: 'Updated Name',
            bio: 'Updated bio',
            isPrivate: true
          }
        })
        .mockResolvedValueOnce({ // Stats retrieval
          Item: {
            eloRating: 1000,
            totalGamesPlayed: 0
          }
        });

      const result = await updateUserProfile(updateEvent);

      expect(result.statusCode).toBe(200);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.user.displayName).toBe('Updated Name');
    });

    it('should handle partial updates', async () => {
      const updateEvent = {
        ...mockEvent,
        body: JSON.stringify({
          displayName: 'Only Name Updated'
        })
      };

      mockDynamoDb.send.mockResolvedValue({});

      const result = await updateUserProfile(updateEvent);

      expect(mockDynamoDb.send).toHaveBeenCalled();
      // Should only update displayName and updatedAt
      const updateCall = mockDynamoDb.send.mock.calls[0][0];
      expect(updateCall.input.UpdateExpression).toContain('#displayName = :displayName');
      expect(updateCall.input.UpdateExpression).toContain('updatedAt = :updatedAt');
      expect(updateCall.input.UpdateExpression).not.toContain('bio');
    });
  });

  describe('getLeaderboard', () => {
    const mockLeaderboardData = [
      {
        userId: 'user1',
        eloRating: 1500,
        totalWins: 30,
        totalLosses: 10,
        currentStreak: 5
      },
      {
        userId: 'user2',
        eloRating: 1450,
        totalWins: 25,
        totalLosses: 15,
        currentStreak: 2
      }
    ];

    const mockProfiles = [
      {
        userId: 'user1',
        username: 'topplayer',
        displayName: 'Top Player',
        avatarURL: 'https://example.com/avatar1.jpg'
      },
      {
        userId: 'user2',
        username: 'secondplace',
        displayName: 'Second Place'
      }
    ];

    it('should return leaderboard with user profiles', async () => {
      mockRedis.get.mockResolvedValue(null); // No cache
      
      mockDynamoDb.send
        .mockResolvedValueOnce({ Items: mockLeaderboardData }) // Leaderboard query
        .mockResolvedValueOnce({ Item: mockProfiles[0] }) // Profile 1
        .mockResolvedValueOnce({ Item: mockProfiles[1] }); // Profile 2

      const result = await getLeaderboard(mockEvent);

      expect(result.statusCode).toBe(200);
      
      const responseBody = JSON.parse(result.body);
      expect(responseBody.entries).toHaveLength(2);
      expect(responseBody.entries[0]).toEqual({
        rank: 1,
        userId: 'user1',
        username: 'topplayer',
        displayName: 'Top Player',
        eloRating: 1500,
        rankTitle: 'Green Thumb',
        totalWins: 30,
        totalGamesPlayed: 40,
        winRate: 75,
        currentStreak: 5,
        avatarURL: 'https://example.com/avatar1.jpg'
      });
    });

    it('should return cached leaderboard when available', async () => {
      const cachedData = JSON.stringify({ entries: [] });
      mockRedis.get.mockResolvedValue(cachedData);

      const result = await getLeaderboard(mockEvent);

      expect(result.statusCode).toBe(200);
      expect(mockDynamoDb.send).not.toHaveBeenCalled();
    });

    it('should handle pagination parameters', async () => {
      const paginatedEvent = {
        ...mockEvent,
        queryStringParameters: {
          limit: '10',
          offset: '20'
        }
      };

      mockRedis.get.mockResolvedValue(null);
      mockDynamoDb.send.mockResolvedValue({ Items: [] });

      await getLeaderboard(paginatedEvent);

      const queryCall = mockDynamoDb.send.mock.calls[0][0];
      expect(queryCall.input.Limit).toBe(30); // limit + offset
    });

    it('should cache leaderboard results', async () => {
      mockRedis.get.mockResolvedValue(null);
      mockDynamoDb.send.mockResolvedValue({ Items: [] });

      await getLeaderboard(mockEvent);

      expect(mockRedis.setEx).toHaveBeenCalledWith(
        'leaderboard:50:0',
        300,
        expect.any(String)
      );
    });
  });

  describe('getUserStats', () => {
    it('should return user achievements', async () => {
      const mockStats = {
        totalWins: 15,
        plantsIdentified: 75,
        longestStreak: 8,
        rankHistory: [
          { rank: 'Sprout', achievedAt: '2023-01-01T00:00:00Z' }
        ],
        lastGameAt: '2023-06-01T00:00:00Z'
      };

      mockDynamoDb.send.mockResolvedValue({ Item: mockStats });

      const result = await getUserStats(mockEvent);

      expect(result.statusCode).toBe(200);
      
      const responseBody = JSON.parse(result.body);
      expect(responseBody.achievements).toBeDefined();
      expect(Array.isArray(responseBody.achievements)).toBe(true);
      
      // Should have various achievements
      const achievements = responseBody.achievements;
      const firstWin = achievements.find((a: any) => a.id === 'first_win');
      expect(firstWin.isUnlocked).toBe(true);
    });

    it('should return empty achievements for new user', async () => {
      mockDynamoDb.send.mockResolvedValue({}); // No stats found

      const result = await getUserStats(mockEvent);

      expect(result.statusCode).toBe(200);
      const responseBody = JSON.parse(result.body);
      expect(responseBody.achievements).toEqual([]);
    });
  });

  describe('updateUserELO', () => {
    it('should update user ELO and stats', async () => {
      const mockCurrentStats = {
        userId: 'test-user',
        eloRating: 1000,
        rank: 'Sprout',
        totalGamesPlayed: 10,
        currentStreak: 2,
        longestStreak: 5,
        rankHistory: []
      };

      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: mockCurrentStats }) // Get current stats
        .mockResolvedValueOnce({}); // Update operation

      await updateUserELO('test-user', 1050, 50, 'win', {
        accuracyRate: 0.8,
        averageResponseTime: 4000,
        plantsIdentified: 8
      });

      expect(mockDynamoDb.send).toHaveBeenCalledTimes(2);
      
      const updateCall = mockDynamoDb.send.mock.calls[1][0];
      expect(updateCall.input.ExpressionAttributeValues[':eloRating']).toBe(1050);
      expect(updateCall.input.ExpressionAttributeValues[':wins']).toBe(1);
      expect(updateCall.input.ExpressionAttributeValues[':losses']).toBe(0);
    });

    it('should handle rank changes', async () => {
      const mockCurrentStats = {
        userId: 'test-user',
        eloRating: 1190,
        rank: 'Sprout',
        rankHistory: []
      };

      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: mockCurrentStats })
        .mockResolvedValueOnce({});

      await updateUserELO('test-user', 1220, 30, 'win', {
        accuracyRate: 0.9,
        averageResponseTime: 3000,
        plantsIdentified: 9
      });

      const updateCall = mockDynamoDb.send.mock.calls[1][0];
      const rankHistory = updateCall.input.ExpressionAttributeValues[':rankHistory'];
      
      expect(rankHistory).toHaveLength(1);
      expect(rankHistory[0].rank).toBe('Green Thumb');
      expect(rankHistory[0].eloRating).toBe(1220);
    });

    it('should update win/loss streaks correctly', async () => {
      const winningStats = {
        userId: 'test-user',
        currentStreak: 3 // Positive streak
      };

      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: winningStats })
        .mockResolvedValueOnce({});

      await updateUserELO('test-user', 1050, 25, 'win', {
        accuracyRate: 0.8,
        averageResponseTime: 4000,
        plantsIdentified: 8
      });

      const updateCall = mockDynamoDb.send.mock.calls[1][0];
      expect(updateCall.input.ExpressionAttributeValues[':currentStreak']).toBe(4);
    });

    it('should initialize stats for new user', async () => {
      mockDynamoDb.send
        .mockResolvedValueOnce({}) // No existing stats
        .mockResolvedValueOnce({}) // Initialize stats
        .mockResolvedValueOnce({}); // Update stats

      await updateUserELO('new-user', 1030, 30, 'win', {
        accuracyRate: 0.7,
        averageResponseTime: 5000,
        plantsIdentified: 7
      });

      expect(mockDynamoDb.send).toHaveBeenCalledTimes(3);
    });

    it('should invalidate leaderboard cache', async () => {
      mockDynamoDb.send
        .mockResolvedValueOnce({ Item: {} })
        .mockResolvedValueOnce({});
      
      mockRedis.keys.mockResolvedValue(['leaderboard:50:0', 'leaderboard:100:0']);

      await updateUserELO('test-user', 1100, 20, 'win', {
        accuracyRate: 0.8,
        averageResponseTime: 4000,
        plantsIdentified: 8
      });

      expect(mockRedis.del).toHaveBeenCalledWith(['leaderboard:50:0', 'leaderboard:100:0']);
    });
  });

  describe('Achievement System', () => {
    it('should unlock achievements based on user stats', async () => {
      const userStats = {
        totalWins: 10,
        plantsIdentified: 60,
        longestStreak: 6,
        rankHistory: [
          { rank: 'Sprout', achievedAt: '2023-01-01' },
          { rank: 'Green Thumb', achievedAt: '2023-02-01' }
        ]
      };

      mockDynamoDb.send.mockResolvedValue({ Item: userStats });

      const result = await getUserStats(mockEvent);
      const achievements = JSON.parse(result.body).achievements;

      // Check specific achievements
      const firstWin = achievements.find((a: any) => a.id === 'first_win');
      expect(firstWin.isUnlocked).toBe(true);

      const plantNovice = achievements.find((a: any) => a.id === 'plant_novice');
      expect(plantNovice.isUnlocked).toBe(true);
      expect(plantNovice.progress).toBe(50); // Capped at maxProgress

      const streakMaster = achievements.find((a: any) => a.id === 'streak_master');
      expect(streakMaster.isUnlocked).toBe(true);

      const greenThumbRank = achievements.find((a: any) => a.id === 'rank_green_thumb');
      expect(greenThumbRank.isUnlocked).toBe(true);
    });

    it('should show progress for incomplete achievements', async () => {
      const userStats = {
        totalWins: 0,
        plantsIdentified: 30,
        longestStreak: 3,
        rankHistory: [{ rank: 'Seedling', achievedAt: '2023-01-01' }]
      };

      mockDynamoDb.send.mockResolvedValue({ Item: userStats });

      const result = await getUserStats(mockEvent);
      const achievements = JSON.parse(result.body).achievements;

      const firstWin = achievements.find((a: any) => a.id === 'first_win');
      expect(firstWin.isUnlocked).toBe(false);
      expect(firstWin.progress).toBe(0);

      const plantNovice = achievements.find((a: any) => a.id === 'plant_novice');
      expect(plantNovice.isUnlocked).toBe(false);
      expect(plantNovice.progress).toBe(30);
      expect(plantNovice.maxProgress).toBe(50);
    });
  });

  describe('Error Handling and Edge Cases', () => {
    it('should handle Redis connection failures gracefully', async () => {
      mockRedis.get.mockRejectedValue(new Error('Redis connection failed'));
      mockDynamoDb.send.mockResolvedValue({ Items: [] });

      const result = await getLeaderboard(mockEvent);

      expect(result.statusCode).toBe(200); // Should still work without cache
    });

    it('should handle malformed request bodies', async () => {
      const malformedEvent = {
        ...mockEvent,
        body: 'invalid json'
      };

      const result = await updateUserProfile(malformedEvent);

      expect(result.statusCode).toBe(500);
    });

    it('should handle concurrent ELO updates', async () => {
      // Simulate rapid succession of ELO updates
      const promises = [];
      
      for (let i = 0; i < 5; i++) {
        mockDynamoDb.send
          .mockResolvedValueOnce({ Item: { eloRating: 1000 + i * 10 } })
          .mockResolvedValueOnce({});
        
        promises.push(
          updateUserELO(`user${i}`, 1050 + i * 10, 20, 'win', {
            accuracyRate: 0.8,
            averageResponseTime: 4000,
            plantsIdentified: 8
          })
        );
      }

      await Promise.all(promises);

      expect(mockDynamoDb.send).toHaveBeenCalledTimes(10); // 2 calls per update
    });
  });
});