import {
  calculateELOChange,
  updateELORatings,
  getRankFromRating,
  getMatchmakingRange,
  simulateELOProgression,
  calculateWinProbability,
  PlayerRating,
  GameResult,
} from "../eloRanking";

describe("ELO Ranking System", () => {
  describe("calculateELOChange", () => {
    it("should calculate ELO change for a win against equal opponent", () => {
      const change = calculateELOChange(1000, 1000, 1, 10);
      expect(change).toBe(20); // K-factor 40 * (1 - 0.5) = 20 for new players
    });

    it("should calculate larger change for upset win", () => {
      const change = calculateELOChange(1000, 1400, 1, 10);
      expect(change).toBeGreaterThan(25); // Should be significant gain
    });

    it("should calculate smaller change for expected win", () => {
      const change = calculateELOChange(1400, 1000, 1, 10);
      expect(change).toBeLessThan(10); // Should be small gain
    });

    it("should use higher K-factor for new players", () => {
      const newPlayerChange = calculateELOChange(1000, 1000, 1, 5);
      const experiencedPlayerChange = calculateELOChange(1000, 1000, 1, 50);
      expect(newPlayerChange).toBeGreaterThan(experiencedPlayerChange);
    });

    it("should use lower K-factor for high-rated players", () => {
      const highRatedChange = calculateELOChange(2100, 2100, 1, 100);
      const normalRatedChange = calculateELOChange(1500, 1500, 1, 100);
      expect(highRatedChange).toBeLessThan(normalRatedChange);
    });
  });

  describe("updateELORatings", () => {
    const winner: PlayerRating = {
      userId: "winner",
      currentRating: 1200,
      gamesPlayed: 25,
      rank: "Green Thumb",
    };

    const loser: PlayerRating = {
      userId: "loser",
      currentRating: 1180,
      gamesPlayed: 30,
      rank: "Green Thumb",
    };

    const gameResult: GameResult = {
      winner: "winner",
      loser: "loser",
      winnerScore: 800,
      loserScore: 600,
      roundsPlayed: 10,
      averageResponseTime: 4000,
      accuracyRate: 0.8,
    };

    it("should update both players ratings correctly", () => {
      const results = updateELORatings(winner, loser, gameResult);

      expect(results.winner.newRating).toBeGreaterThan(winner.currentRating);
      expect(results.loser.newRating).toBeLessThan(loser.currentRating);
      expect(results.winner.ratingChange).toBeGreaterThan(0);
      expect(results.loser.ratingChange).toBeLessThan(0);
    });

    it("should award performance bonuses for exceptional play", () => {
      const dominantGameResult: GameResult = {
        ...gameResult,
        winnerScore: 1000,
        loserScore: 200,
        averageResponseTime: 2000, // Very fast
        accuracyRate: 0.95, // Very accurate
      };

      const results = updateELORatings(winner, loser, dominantGameResult);
      expect(results.winner.ratingChange).toBeGreaterThan(20); // Should include bonuses
    });

    it("should limit maximum rating loss", () => {
      const hugeLoss: GameResult = {
        ...gameResult,
        winnerScore: 1000,
        loserScore: 0,
        averageResponseTime: 10000,
        accuracyRate: 0.1,
      };

      const highRatedLoser: PlayerRating = {
        ...loser,
        currentRating: 2000,
      };

      const results = updateELORatings(winner, highRatedLoser, hugeLoss);
      expect(Math.abs(results.loser.ratingChange)).toBeLessThanOrEqual(50);
    });

    it("should prevent ratings from going below 100", () => {
      const lowRatedLoser: PlayerRating = {
        ...loser,
        currentRating: 120,
      };

      const results = updateELORatings(winner, lowRatedLoser, gameResult);
      expect(results.loser.newRating).toBeGreaterThanOrEqual(100);
    });

    it("should update ranks when crossing thresholds", () => {
      const nearPromotionWinner: PlayerRating = {
        ...winner,
        currentRating: 1195,
        rank: "Sprout",
      };

      const results = updateELORatings(nearPromotionWinner, loser, gameResult);

      if (results.winner.newRating >= 1200) {
        expect(results.winner.rankChanged).toBe(true);
        expect(results.winner.newRank).toBe("Green Thumb");
      }
    });
  });

  describe("getRankFromRating", () => {
    it("should return correct ranks for rating ranges", () => {
      expect(getRankFromRating(500)).toBe("New Gardener");
      expect(getRankFromRating(800)).toBe("Seedling");
      expect(getRankFromRating(1000)).toBe("Sprout");
      expect(getRankFromRating(1200)).toBe("Green Thumb");
      expect(getRankFromRating(1400)).toBe("Plant Enthusiast");
      expect(getRankFromRating(1600)).toBe("Gardener");
      expect(getRankFromRating(1800)).toBe("Botanist");
      expect(getRankFromRating(2000)).toBe("Plant Scientist");
      expect(getRankFromRating(2200)).toBe("Flora Expert");
      expect(getRankFromRating(2500)).toBe("Botanical Master");
    });

    it("should handle edge cases", () => {
      expect(getRankFromRating(0)).toBe("New Gardener");
      expect(getRankFromRating(9999)).toBe("Botanical Master");
    });
  });

  describe("getMatchmakingRange", () => {
    it("should return base range for short wait times", () => {
      const range = getMatchmakingRange(1500, 10000); // 10 seconds
      expect(range.min).toBe(1350);
      expect(range.max).toBe(1650);
    });

    it("should expand range for longer wait times", () => {
      const shortRange = getMatchmakingRange(1500, 10000);
      const longRange = getMatchmakingRange(1500, 120000); // 2 minutes

      expect(longRange.max - longRange.min).toBeGreaterThan(
        shortRange.max - shortRange.min,
      );
    });

    it("should cap maximum range", () => {
      const range = getMatchmakingRange(1500, 600000); // 10 minutes
      expect(range.max - range.min).toBeLessThanOrEqual(1000); // Max range cap
    });

    it("should not go below minimum rating", () => {
      const range = getMatchmakingRange(200, 600000);
      expect(range.min).toBeGreaterThanOrEqual(100);
    });
  });

  describe("simulateELOProgression", () => {
    it("should increase rating with more wins than losses", () => {
      const finalRating = simulateELOProgression(1000, 7, 3, 1000);
      expect(finalRating).toBeGreaterThan(1000);
    });

    it("should decrease rating with more losses than wins", () => {
      const finalRating = simulateELOProgression(1000, 3, 7, 1000);
      expect(finalRating).toBeLessThan(1000);
    });

    it("should maintain rating with equal wins and losses", () => {
      const finalRating = simulateELOProgression(1000, 5, 5, 1000);
      expect(Math.abs(finalRating - 1000)).toBeLessThan(50); // Should be close to starting
    });
  });

  describe("calculateWinProbability", () => {
    it("should return 0.5 for equal ratings", () => {
      const probability = calculateWinProbability(1500, 1500);
      expect(probability).toBeCloseTo(0.5, 2);
    });

    it("should return higher probability for higher rated player", () => {
      const probability = calculateWinProbability(1600, 1400);
      expect(probability).toBeGreaterThan(0.5);
    });

    it("should return lower probability for lower rated player", () => {
      const probability = calculateWinProbability(1400, 1600);
      expect(probability).toBeLessThan(0.5);
    });

    it("should handle extreme rating differences", () => {
      const highProb = calculateWinProbability(2000, 1000);
      const lowProb = calculateWinProbability(1000, 2000);

      expect(highProb).toBeGreaterThan(0.9);
      expect(lowProb).toBeLessThan(0.1);
      expect(highProb + lowProb).toBeCloseTo(1, 2);
    });
  });

  describe("Integration Tests", () => {
    it("should maintain rating conservation in head-to-head matches", () => {
      const player1: PlayerRating = {
        userId: "player1",
        currentRating: 1500,
        gamesPlayed: 50,
        rank: "Plant Enthusiast",
      };

      const player2: PlayerRating = {
        userId: "player2",
        currentRating: 1500,
        gamesPlayed: 50,
        rank: "Plant Enthusiast",
      };

      const gameResult: GameResult = {
        winner: "player1",
        loser: "player2",
        winnerScore: 700,
        loserScore: 500,
        roundsPlayed: 10,
        averageResponseTime: 5000,
        accuracyRate: 0.7,
      };

      const results = updateELORatings(player1, player2, gameResult);

      // Rating changes should be roughly equal and opposite (allowing for bonuses)
      const totalChange =
        results.winner.ratingChange + Math.abs(results.loser.ratingChange);
      expect(totalChange).toBeLessThan(40); // Should be close to zero-sum
    });

    it("should handle rapid rating progression for new players", () => {
      let currentRating = 1000;
      const baseOpponentRating = 1200;

      // Simulate new player winning against stronger opponents
      for (let i = 0; i < 10; i++) {
        const change = calculateELOChange(
          currentRating,
          baseOpponentRating,
          1,
          i,
        );
        currentRating += change;
      }

      expect(currentRating).toBeGreaterThan(1150); // Should climb quickly
      expect(getRankFromRating(currentRating)).toBe("Green Thumb");
    });

    it("should stabilize ratings for experienced players", () => {
      let currentRating = 1800;
      const opponentRating = 1800;

      // Simulate alternating wins and losses for experienced player
      for (let i = 0; i < 20; i++) {
        const result = i % 2 === 0 ? 1 : 0; // Alternating wins/losses
        const change = calculateELOChange(
          currentRating,
          opponentRating,
          result,
          100 + i,
        );
        currentRating += change;
      }

      // Rating should remain relatively stable
      expect(Math.abs(currentRating - 1800)).toBeLessThan(100);
    });
  });
});
