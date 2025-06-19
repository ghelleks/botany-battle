// Create mock functions first
const mockRedis = {
  hgetall: jest.fn(),
  hset: jest.fn(),
  hdel: jest.fn(),
  expire: jest.fn(),
  get: jest.fn(),
  setex: jest.fn(),
  del: jest.fn()
};

// Create DynamoDB mock function
const mockSend = jest.fn();

// Mock Redis constructor
jest.mock('ioredis', () => {
  return jest.fn().mockImplementation(() => mockRedis);
});

// Mock DynamoDB
jest.mock('@aws-sdk/lib-dynamodb', () => ({
  DynamoDBDocumentClient: {
    from: jest.fn(() => ({
      send: mockSend
    }))
  },
  GetCommand: jest.fn()
}));

// Mock ELO functions
jest.mock('../eloRanking', () => ({
  updateELORatings: jest.fn(),
  getMatchmakingRange: jest.fn((rating: number) => {
    // Return a range that makes sense for the given rating
    const range = 150; // Base range
    return { 
      min: Math.max(100, rating - range), 
      max: rating + range 
    };
  })
}));

// Mock user service
jest.mock('../../user/handler', () => ({
  updateUserELO: jest.fn()
}));

// Import handler after mocks are set up
import { 
  findELOBasedOpponent,
  addToMatchmakingQueue,
  removeFromMatchmakingQueue,
  finalizeGame,
  getUserStats 
} from '../handler';

describe('Game Logic', () => {
  let mockDynamoDb: any;

  beforeEach(() => {
    jest.clearAllMocks();
    
    // Setup DynamoDB mock
    const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
    mockDynamoDb = DynamoDBDocumentClient.from();
  });

  describe('Matchmaking System', () => {
    describe('addToMatchmakingQueue', () => {
      it('should add player to queue with ELO rating and timestamp', async () => {
        const userId = 'user123';
        const eloRating = 1200;
        
        await addToMatchmakingQueue(userId, eloRating);
        
        expect(mockRedis.hset).toHaveBeenCalledWith(
          'matchmaking:players',
          userId,
          expect.stringContaining('"eloRating":1200')
        );
        expect(mockRedis.expire).toHaveBeenCalledWith('matchmaking:players', 600);
      });
    });

    describe('removeFromMatchmakingQueue', () => {
      it('should remove player from queue', async () => {
        const userId = 'user123';
        
        await removeFromMatchmakingQueue(userId);
        
        expect(mockRedis.hdel).toHaveBeenCalledWith('matchmaking:players', userId);
      });
    });

    describe('findELOBasedOpponent', () => {
      it('should return null when no players in queue', async () => {
        mockRedis.hgetall.mockResolvedValue({});
        
        const opponent = await findELOBasedOpponent('user123', 1000);
        
        expect(opponent).toBeNull();
      });

      it('should find suitable opponent within ELO range', async () => {
        const waitingPlayers = {
          'user456': JSON.stringify({
            eloRating: 1020,
            joinTime: Date.now() - 30000 // 30 seconds ago
          }),
          'user789': JSON.stringify({
            eloRating: 1500, // Too far
            joinTime: Date.now() - 30000
          })
        };
        
        mockRedis.hgetall.mockResolvedValue(waitingPlayers);
        
        const opponent = await findELOBasedOpponent('user123', 1000);
        
        expect(opponent).toEqual({
          userId: 'user456',
          eloRating: 1020,
          waitTime: expect.any(Number)
        });
      });

      it('should exclude self from opponent search', async () => {
        const waitingPlayers = {
          'user123': JSON.stringify({
            eloRating: 1000,
            joinTime: Date.now() - 30000
          })
        };
        
        mockRedis.hgetall.mockResolvedValue(waitingPlayers);
        
        const opponent = await findELOBasedOpponent('user123', 1000);
        
        expect(opponent).toBeNull();
      });

      it('should prefer closer ELO matches', async () => {
        const waitingPlayers = {
          'close_match': JSON.stringify({
            eloRating: 1005,
            joinTime: Date.now() - 30000
          }),
          'far_match': JSON.stringify({
            eloRating: 1040,
            joinTime: Date.now() - 30000
          })
        };
        
        mockRedis.hgetall.mockResolvedValue(waitingPlayers);
        
        const opponent = await findELOBasedOpponent('user123', 1000);
        
        expect(opponent?.userId).toBe('close_match');
      });

      it('should factor in wait time for matchmaking', async () => {
        const waitingPlayers = {
          'recent_player': JSON.stringify({
            eloRating: 1040,
            joinTime: Date.now() - 10000 // 10 seconds ago
          }),
          'waiting_player': JSON.stringify({
            eloRating: 1040,
            joinTime: Date.now() - 120000 // 2 minutes ago
          })
        };
        
        mockRedis.hgetall.mockResolvedValue(waitingPlayers);
        
        const opponent = await findELOBasedOpponent('user123', 1000);
        
        // Should prefer the player who has been waiting longer
        expect(opponent?.userId).toBe('waiting_player');
      });
    });
  });

  describe('Game State Management', () => {
    describe('getUserStats', () => {
      it('should return user stats from database', async () => {
        const mockUserStats = {
          eloRating: 1250,
          totalGamesPlayed: 42
        };
        
        mockSend.mockResolvedValue({
          Item: mockUserStats
        });
        
        const stats = await getUserStats('user123');
        
        expect(stats).toEqual({
          eloRating: 1250,
          gamesPlayed: 42
        });
      });

      it('should return default stats for new user', async () => {
        mockSend.mockResolvedValue({});
        
        const stats = await getUserStats('newuser');
        
        expect(stats).toEqual({
          eloRating: 1000,
          gamesPlayed: 0
        });
      });

      it('should handle database errors gracefully', async () => {
        mockSend.mockRejectedValue(new Error('Database error'));
        
        const stats = await getUserStats('user123');
        
        expect(stats).toEqual({
          eloRating: 1000,
          gamesPlayed: 0
        });
      });
    });

    describe('finalizeGame', () => {
      const mockGameState = {
        gameId: 'game123',
        players: ['player1', 'player2'],
        scores: { player1: 800, player2: 600 },
        playerStats: {
          player1: {
            correctAnswers: 8,
            totalAnswers: 10,
            averageResponseTime: 3500,
            eloRating: 1200
          },
          player2: {
            correctAnswers: 6,
            totalAnswers: 10,
            averageResponseTime: 4200,
            eloRating: 1180
          }
        },
        maxRounds: 10,
        status: 'completed'
      };

      beforeEach(() => {
        // Mock ELO calculation results
        const { updateELORatings } = require('../eloRanking');
        updateELORatings.mockReturnValue({
          winner: {
            newRating: 1220,
            ratingChange: 20,
            newRank: 'Green Thumb',
            rankChanged: false
          },
          loser: {
            newRating: 1160,
            ratingChange: -20,
            newRank: 'Sprout',
            rankChanged: false
          }
        });

        // Mock getUserStats
        mockSend.mockResolvedValue({
          Item: { totalGamesPlayed: 25 }
        });
      });

      it('should determine winner correctly by score', async () => {
        await finalizeGame(mockGameState);
        
        expect(mockGameState.winner).toBe('player1');
      });

      it('should handle tie by accuracy rate', async () => {
        const tiedGameState = {
          ...mockGameState,
          scores: { player1: 600, player2: 600 },
          playerStats: {
            player1: {
              correctAnswers: 6,
              totalAnswers: 10,
              averageResponseTime: 4000,
              eloRating: 1200
            },
            player2: {
              correctAnswers: 7,
              totalAnswers: 10,
              averageResponseTime: 3500,
              eloRating: 1180
            }
          }
        };

        await finalizeGame(tiedGameState);
        
        expect(tiedGameState.winner).toBe('player2'); // Higher accuracy
      });

      it('should handle tie by response time when accuracy is equal', async () => {
        const tiedGameState = {
          ...mockGameState,
          scores: { player1: 600, player2: 600 },
          playerStats: {
            player1: {
              correctAnswers: 6,
              totalAnswers: 10,
              averageResponseTime: 3000, // Faster
              eloRating: 1200
            },
            player2: {
              correctAnswers: 6,
              totalAnswers: 10,
              averageResponseTime: 4000,
              eloRating: 1180
            }
          }
        };

        await finalizeGame(tiedGameState);
        
        expect(tiedGameState.winner).toBe('player1'); // Faster response
      });

      it('should calculate and store ELO changes', async () => {
        await finalizeGame(mockGameState);
        
        expect(mockGameState.eloChanges).toEqual({
          player1: 20,
          player2: -20
        });
      });

      it('should update user ELO ratings in database', async () => {
        const { updateUserELO } = require('../../user/handler');
        
        await finalizeGame(mockGameState);
        
        expect(updateUserELO).toHaveBeenCalledTimes(2);
        expect(updateUserELO).toHaveBeenCalledWith(
          'player1',
          1220,
          20,
          'win',
          expect.objectContaining({
            accuracyRate: 0.8,
            averageResponseTime: 3500,
            plantsIdentified: 8
          })
        );
        expect(updateUserELO).toHaveBeenCalledWith(
          'player2',
          1160,
          -20,
          'loss',
          expect.objectContaining({
            accuracyRate: 0.6,
            averageResponseTime: 4200,
            plantsIdentified: 6
          })
        );
      });
    });
  });

  describe('Game Flow Integration', () => {
    it('should handle complete game flow from matchmaking to completion', async () => {
      // 1. Add players to queue (these will be mocked calls)
      await addToMatchmakingQueue('player1', 1200);
      await addToMatchmakingQueue('player2', 1180);
      
      // 2. Set up mock for finding match (after beforeEach clears mocks)
      mockRedis.hgetall.mockResolvedValue({
        'player2': JSON.stringify({
          eloRating: 1180,
          joinTime: Date.now() - 30000
        })
      });
      
      const opponent = await findELOBasedOpponent('player1', 1200);
      expect(opponent).toBeTruthy();
      expect(opponent?.userId).toBe('player2');
      expect(opponent?.eloRating).toBe(1180);
      
      // 3. Remove matched players from queue
      await removeFromMatchmakingQueue('player2');
      
      // 4. Game completion
      const gameState = {
        gameId: 'test-game',
        players: ['player1', 'player2'],
        scores: { player1: 900, player2: 700 },
        playerStats: {
          player1: {
            correctAnswers: 9,
            totalAnswers: 10,
            averageResponseTime: 3000,
            eloRating: 1200
          },
          player2: {
            correctAnswers: 7,
            totalAnswers: 10,
            averageResponseTime: 4000,
            eloRating: 1180
          }
        },
        maxRounds: 10,
        status: 'completed'
      };
      
      // Mock getUserStats calls for finalizeGame
      mockSend.mockResolvedValue({
        Item: { totalGamesPlayed: 25 }
      });
      
      await finalizeGame(gameState);
      
      expect(gameState.winner).toBe('player1');
      expect(gameState.eloChanges).toBeDefined();
    });

    it('should handle errors gracefully in game finalization', async () => {
      const { updateUserELO } = require('../../user/handler');
      updateUserELO.mockRejectedValue(new Error('Database error'));
      
      const gameState = {
        gameId: 'error-game',
        players: ['player1', 'player2'],
        scores: { player1: 800, player2: 600 },
        playerStats: {
          player1: {
            correctAnswers: 8,
            totalAnswers: 10,
            averageResponseTime: 3500,
            eloRating: 1200
          },
          player2: {
            correctAnswers: 6,
            totalAnswers: 10,
            averageResponseTime: 4200,
            eloRating: 1180
          }
        },
        maxRounds: 10,
        status: 'completed'
      };
      
      // Should not throw error
      await expect(finalizeGame(gameState)).resolves.not.toThrow();
    });
  });

  describe('Performance and Edge Cases', () => {
    it('should handle large numbers of waiting players efficiently', async () => {
      const manyPlayers: Record<string, string> = {};
      
      for (let i = 0; i < 1000; i++) {
        manyPlayers[`player${i}`] = JSON.stringify({
          eloRating: 1000 + (i % 400), // Spread ratings from 1000-1400
          joinTime: Date.now() - (i * 1000) // Different join times
        });
      }
      
      mockRedis.hgetall.mockResolvedValue(manyPlayers);
      
      const startTime = Date.now();
      const opponent = await findELOBasedOpponent('testuser', 1200);
      const endTime = Date.now();
      
      expect(opponent).toBeTruthy();
      expect(endTime - startTime).toBeLessThan(100); // Should be fast
    });

    it('should handle extreme ELO ratings', async () => {
      const extremeGameState = {
        gameId: 'extreme-game',
        players: ['master', 'beginner'],
        scores: { master: 1000, beginner: 100 },
        playerStats: {
          master: {
            correctAnswers: 10,
            totalAnswers: 10,
            averageResponseTime: 2000,
            eloRating: 2500 // Very high
          },
          beginner: {
            correctAnswers: 1,
            totalAnswers: 10,
            averageResponseTime: 8000,
            eloRating: 500 // Very low
          }
        },
        maxRounds: 10,
        status: 'completed'
      };
      
      await finalizeGame(extremeGameState);
      
      expect(extremeGameState.winner).toBe('master');
      expect(extremeGameState.eloChanges).toBeDefined();
    });

    it('should maintain ELO rating bounds', async () => {
      const stats = await getUserStats('user123');
      
      expect(stats?.eloRating).toBeGreaterThanOrEqual(100);
      expect(stats?.gamesPlayed).toBeGreaterThanOrEqual(0);
    });
  });
});