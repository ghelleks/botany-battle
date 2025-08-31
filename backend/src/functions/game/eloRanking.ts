/**
 * ELO Ranking System Implementation for Botany Battle
 *
 * Standard ELO rating system adapted for plant identification game:
 * - K-factor varies by rating level for balanced progression
 * - Bonus points for speed and accuracy
 * - Rank tiers based on ELO ranges
 */

export interface ELOResult {
  newRating: number;
  ratingChange: number;
  newRank: string;
  rankChanged: boolean;
}

export interface GameResult {
  winner: string;
  loser: string;
  winnerScore: number;
  loserScore: number;
  roundsPlayed: number;
  averageResponseTime: number;
  accuracyRate: number;
}

export interface PlayerRating {
  userId: string;
  currentRating: number;
  gamesPlayed: number;
  rank: string;
}

/**
 * ELO rating calculation with adaptive K-factor
 */
export function calculateELOChange(
  playerRating: number,
  opponentRating: number,
  gameResult: 0 | 0.5 | 1, // 0 = loss, 0.5 = draw, 1 = win
  gamesPlayed: number,
): number {
  // K-factor (rating volatility) based on experience and rating level
  const kFactor = getKFactor(playerRating, gamesPlayed);

  // Expected score using standard ELO formula
  const expectedScore =
    1 / (1 + Math.pow(10, (opponentRating - playerRating) / 400));

  // Rating change
  const ratingChange = Math.round(kFactor * (gameResult - expectedScore));

  return ratingChange;
}

/**
 * Adaptive K-factor for balanced progression
 */
function getKFactor(rating: number, gamesPlayed: number): number {
  // New players (first 30 games) have higher volatility
  if (gamesPlayed < 30) {
    return 40;
  }

  // High-rated players have lower volatility for stability
  if (rating >= 2000) {
    return 16;
  }

  // Intermediate players
  if (rating >= 1500) {
    return 24;
  }

  // Lower-rated players maintain some volatility for improvement
  return 32;
}

/**
 * Calculate new ELO ratings for both players after a game
 */
export function updateELORatings(
  winner: PlayerRating,
  loser: PlayerRating,
  gameResult: GameResult,
): { winner: ELOResult; loser: ELOResult } {
  // Base ELO calculation
  const winnerChange = calculateELOChange(
    winner.currentRating,
    loser.currentRating,
    1, // winner gets 1
    winner.gamesPlayed,
  );

  const loserChange = calculateELOChange(
    loser.currentRating,
    winner.currentRating,
    0, // loser gets 0
    loser.gamesPlayed,
  );

  // Performance bonus for exceptional play
  const winnerBonus = calculatePerformanceBonus(gameResult, true);
  const loserBonus = calculatePerformanceBonus(gameResult, false);

  // Calculate new ratings
  const winnerNewRating = Math.max(
    100,
    winner.currentRating + winnerChange + winnerBonus,
  );
  const loserNewRating = Math.max(
    100,
    loser.currentRating + loserChange + loserBonus,
  );

  // Determine ranks
  const winnerNewRank = getRankFromRating(winnerNewRating);
  const loserNewRank = getRankFromRating(loserNewRating);

  return {
    winner: {
      newRating: winnerNewRating,
      ratingChange: winnerChange + winnerBonus,
      newRank: winnerNewRank,
      rankChanged: winnerNewRank !== winner.rank,
    },
    loser: {
      newRating: loserNewRating,
      ratingChange: loserChange + loserBonus,
      newRank: loserNewRank,
      rankChanged: loserNewRank !== loser.rank,
    },
  };
}

/**
 * Performance bonus based on game statistics
 */
function calculatePerformanceBonus(
  gameResult: GameResult,
  isWinner: boolean,
): number {
  let bonus = 0;

  if (isWinner) {
    // Bonus for dominant performance
    const scoreDifferential = gameResult.winnerScore - gameResult.loserScore;
    if (scoreDifferential >= 500) {
      bonus += 5; // Dominant victory
    } else if (scoreDifferential >= 300) {
      bonus += 3; // Strong victory
    }

    // Speed bonus for fast responses
    if (gameResult.averageResponseTime <= 3000) {
      // 3 seconds
      bonus += 2;
    }

    // Accuracy bonus
    if (gameResult.accuracyRate >= 0.9) {
      bonus += 3;
    } else if (gameResult.accuracyRate >= 0.8) {
      bonus += 1;
    }
  } else {
    // Consolation points for good performance in loss
    if (gameResult.accuracyRate >= 0.8) {
      bonus += 1; // Reduce rating loss for good accuracy
    }

    // Limit maximum rating loss
    const potentialLoss = Math.abs(bonus);
    if (potentialLoss > 50) {
      bonus = Math.max(bonus, -50); // Cap loss at 50 points
    }
  }

  return bonus;
}

/**
 * Rank system based on ELO rating ranges
 */
export function getRankFromRating(rating: number): string {
  if (rating >= 2400) return "Botanical Master";
  if (rating >= 2200) return "Flora Expert";
  if (rating >= 2000) return "Plant Scientist";
  if (rating >= 1800) return "Botanist";
  if (rating >= 1600) return "Gardener";
  if (rating >= 1400) return "Plant Enthusiast";
  if (rating >= 1200) return "Green Thumb";
  if (rating >= 1000) return "Sprout";
  if (rating >= 800) return "Seedling";
  return "New Gardener";
}

/**
 * Get rating range for each rank
 */
export function getRankRequirements(): Array<{
  rank: string;
  minRating: number;
  maxRating: number;
}> {
  return [
    { rank: "Botanical Master", minRating: 2400, maxRating: 9999 },
    { rank: "Flora Expert", minRating: 2200, maxRating: 2399 },
    { rank: "Plant Scientist", minRating: 2000, maxRating: 2199 },
    { rank: "Botanist", minRating: 1800, maxRating: 1999 },
    { rank: "Gardener", minRating: 1600, maxRating: 1799 },
    { rank: "Plant Enthusiast", minRating: 1400, maxRating: 1599 },
    { rank: "Green Thumb", minRating: 1200, maxRating: 1399 },
    { rank: "Sprout", minRating: 1000, maxRating: 1199 },
    { rank: "Seedling", minRating: 800, maxRating: 999 },
    { rank: "New Gardener", minRating: 0, maxRating: 799 },
  ];
}

/**
 * Calculate matchmaking rating range for a player
 */
export function getMatchmakingRange(
  rating: number,
  waitTime: number,
): { min: number; max: number } {
  // Base range expands with wait time
  let baseRange = 150;

  // Expand range based on wait time (every 30 seconds)
  const expansions = Math.floor(waitTime / 30000);
  const expandedRange = baseRange + expansions * 50;

  // Maximum range cap to maintain game quality
  const maxRange = Math.min(expandedRange, 500);

  return {
    min: Math.max(100, rating - maxRange),
    max: rating + maxRange,
  };
}

/**
 * Simulate ELO progression for testing
 */
export function simulateELOProgression(
  initialRating: number,
  wins: number,
  losses: number,
  averageOpponentRating: number,
): number {
  let currentRating = initialRating;
  let gamesPlayed = 0;

  // Simulate wins
  for (let i = 0; i < wins; i++) {
    const change = calculateELOChange(
      currentRating,
      averageOpponentRating,
      1,
      gamesPlayed,
    );
    currentRating += change;
    gamesPlayed++;
  }

  // Simulate losses
  for (let i = 0; i < losses; i++) {
    const change = calculateELOChange(
      currentRating,
      averageOpponentRating,
      0,
      gamesPlayed,
    );
    currentRating += change;
    gamesPlayed++;
  }

  return Math.max(100, currentRating);
}

/**
 * Calculate expected win rate between two players
 */
export function calculateWinProbability(
  playerRating: number,
  opponentRating: number,
): number {
  return 1 / (1 + Math.pow(10, (opponentRating - playerRating) / 400));
}

/**
 * Generate leaderboard data structure
 */
export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string;
  displayName: string;
  eloRating: number;
  rankTitle: string;
  totalWins: number;
  totalGamesPlayed: number;
  winRate: number;
  currentStreak: number;
  avatarURL?: string;
}

/**
 * Calculate leaderboard statistics
 */
export function calculateLeaderboardStats(
  rating: number,
  wins: number,
  losses: number,
  currentStreak: number,
): Partial<LeaderboardEntry> {
  const totalGames = wins + losses;
  const winRate = totalGames > 0 ? wins / totalGames : 0;

  return {
    eloRating: rating,
    rankTitle: getRankFromRating(rating),
    totalWins: wins,
    totalGamesPlayed: totalGames,
    winRate: Math.round(winRate * 1000) / 10, // Percentage with 1 decimal
    currentStreak: currentStreak,
  };
}
