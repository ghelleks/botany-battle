interface EconomyConfig {
  baseRewards: {
    winRound: number;
    loseRound: number;
    winGame: number;
    loseGame: number;
    firstGame: number;
    dailyBonus: number;
  };
  multipliers: {
    difficultyEasy: number;
    difficultyMedium: number;
    difficultyHard: number;
    streakBonus: number;
    streakThreshold: number;
    perfectGame: number;
  };
  prices: {
    hintBasic: number;
    hintAdvanced: number;
    timeFreeze: number;
    doublePoints: number;
    luckyGuess: number;
    cosmeticMultiplier: number;
  };
  penalties: {
    maxLossStreak: number;
    lossStreakPenalty: number;
    inactivityDays: number;
    inactivityPenalty: number;
  };
}

export class EconomyBalancer {
  private config: EconomyConfig;

  constructor(config?: Partial<EconomyConfig>) {
    this.config = {
      baseRewards: {
        winRound: 10,
        loseRound: 2,
        winGame: 50,
        loseGame: 10,
        firstGame: 100,
        dailyBonus: 25,
      },
      multipliers: {
        difficultyEasy: 1.0,
        difficultyMedium: 1.2,
        difficultyHard: 1.5,
        streakBonus: 0.1,
        streakThreshold: 3,
        perfectGame: 2.0,
      },
      prices: {
        hintBasic: 50,
        hintAdvanced: 100,
        timeFreeze: 75,
        doublePoints: 25,
        luckyGuess: 50,
        cosmeticMultiplier: 10,
      },
      penalties: {
        maxLossStreak: 5,
        lossStreakPenalty: 0.5,
        inactivityDays: 7,
        inactivityPenalty: 0.8,
      },
      ...config,
    };
  }

  calculateRoundReward(
    won: boolean,
    difficulty: "easy" | "medium" | "hard",
    streak: number,
    timeBonus: number = 0,
  ): number {
    const baseReward = won
      ? this.config.baseRewards.winRound
      : this.config.baseRewards.loseRound;

    let multiplier =
      this.config.multipliers[
        `difficulty${difficulty.charAt(0).toUpperCase() + difficulty.slice(1)}`
      ];

    if (won && streak >= this.config.multipliers.streakThreshold) {
      const streakMultiplier =
        1 +
        (streak - this.config.multipliers.streakThreshold + 1) *
          this.config.multipliers.streakBonus;
      multiplier *= Math.min(streakMultiplier, 2.0);
    }

    const timeMultiplier = Math.max(0.5, 1 + timeBonus / 100);

    return Math.round(baseReward * multiplier * timeMultiplier);
  }

  calculateGameReward(
    won: boolean,
    difficulty: "easy" | "medium" | "hard",
    roundsWon: number,
    totalRounds: number,
    gameStreak: number,
    isFirstGame: boolean = false,
  ): number {
    if (isFirstGame) {
      return this.config.baseRewards.firstGame;
    }

    const baseReward = won
      ? this.config.baseRewards.winGame
      : this.config.baseRewards.loseGame;

    let multiplier =
      this.config.multipliers[
        `difficulty${difficulty.charAt(0).toUpperCase() + difficulty.slice(1)}`
      ];

    if (roundsWon === totalRounds && won) {
      multiplier *= this.config.multipliers.perfectGame;
    }

    if (won && gameStreak >= this.config.multipliers.streakThreshold) {
      const streakMultiplier =
        1 +
        (gameStreak - this.config.multipliers.streakThreshold + 1) *
          this.config.multipliers.streakBonus;
      multiplier *= Math.min(streakMultiplier, 2.5);
    }

    const performanceBonus = roundsWon / totalRounds;
    multiplier *= 0.5 + performanceBonus;

    return Math.round(baseReward * multiplier);
  }

  calculateDailyBonus(daysStreak: number): number {
    const baseBonus = this.config.baseRewards.dailyBonus;
    const streakMultiplier = 1 + Math.min(daysStreak - 1, 6) * 0.2;
    return Math.round(baseBonus * streakMultiplier);
  }

  applyPenalties(
    baseReward: number,
    lossStreak: number,
    daysSinceLastPlay: number,
  ): number {
    let penalty = 1.0;

    if (lossStreak >= this.config.penalties.maxLossStreak) {
      const streakPenalty = Math.pow(
        this.config.penalties.lossStreakPenalty,
        Math.min(lossStreak - this.config.penalties.maxLossStreak + 1, 3),
      );
      penalty *= streakPenalty;
    }

    if (daysSinceLastPlay >= this.config.penalties.inactivityDays) {
      penalty *= this.config.penalties.inactivityPenalty;
    }

    return Math.max(1, Math.round(baseReward * penalty));
  }

  calculateItemPrice(
    basePrice: number,
    rarity: "common" | "rare" | "epic" | "legendary",
    category: "powerup" | "cosmetic" | "booster",
    demandFactor: number = 1.0,
  ): number {
    const rarityMultipliers = {
      common: 1.0,
      rare: 2.0,
      epic: 4.0,
      legendary: 8.0,
    };

    const categoryMultipliers = {
      powerup: 1.0,
      cosmetic: this.config.prices.cosmeticMultiplier,
      booster: 1.5,
    };

    const finalPrice = Math.round(
      basePrice *
        rarityMultipliers[rarity] *
        categoryMultipliers[category] *
        demandFactor,
    );

    return Math.max(1, finalPrice);
  }

  validatePlayerEconomy(
    coins: number,
    gems: number,
    gamesPlayed: number,
    gamesWon: number,
  ): {
    isHealthy: boolean;
    issues: string[];
    recommendations: string[];
  } {
    const issues: string[] = [];
    const recommendations: string[] = [];

    const winRate = gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;
    const expectedCoins = this.estimateExpectedCoins(gamesPlayed, winRate);

    if (coins > expectedCoins * 2) {
      issues.push("Potential coin exploitation detected");
      recommendations.push("Review recent transaction history");
    }

    if (coins < expectedCoins * 0.3 && gamesPlayed > 10) {
      issues.push("Player may be struggling with economy");
      recommendations.push("Consider offering daily bonus or tutorial");
    }

    if (gems > gamesPlayed * 2 && gamesPlayed > 0) {
      issues.push("Unusual gem accumulation");
      recommendations.push("Check gem sources");
    }

    if (winRate > 0.9 && gamesPlayed > 20) {
      issues.push("Suspiciously high win rate");
      recommendations.push("Review gameplay for potential cheating");
    }

    if (winRate < 0.1 && gamesPlayed > 10) {
      issues.push("Very low win rate");
      recommendations.push("Suggest difficulty adjustment or hints");
    }

    return {
      isHealthy: issues.length === 0,
      issues,
      recommendations,
    };
  }

  estimateExpectedCoins(gamesPlayed: number, winRate: number): number {
    const avgRoundsPerGame = 5;
    const avgRoundReward =
      this.config.baseRewards.winRound * winRate +
      this.config.baseRewards.loseRound * (1 - winRate);
    const avgGameReward =
      this.config.baseRewards.winGame * winRate +
      this.config.baseRewards.loseGame * (1 - winRate);

    const totalRoundRewards = gamesPlayed * avgRoundsPerGame * avgRoundReward;
    const totalGameRewards = gamesPlayed * avgGameReward;
    const dailyBonuses =
      Math.floor(gamesPlayed / 3) * this.config.baseRewards.dailyBonus;

    return Math.round(totalRoundRewards + totalGameRewards + dailyBonuses);
  }

  adjustDynamicPricing(
    itemId: string,
    currentPrice: number,
    purchaseVolume: number,
    timeWindow: number,
  ): number {
    const targetPurchasesPerWindow = 100;
    const demandRatio = purchaseVolume / targetPurchasesPerWindow;

    let adjustment = 1.0;
    if (demandRatio > 1.5) {
      adjustment = 1.2;
    } else if (demandRatio > 1.2) {
      adjustment = 1.1;
    } else if (demandRatio < 0.5) {
      adjustment = 0.9;
    } else if (demandRatio < 0.3) {
      adjustment = 0.8;
    }

    const newPrice = Math.round(currentPrice * adjustment);
    return Math.max(1, newPrice);
  }

  generateEconomyReport(
    totalCoins: number,
    totalGems: number,
    totalPlayers: number,
    avgGamesPerPlayer: number,
    avgWinRate: number,
  ): {
    status: "healthy" | "inflation" | "deflation" | "critical";
    metrics: Record<string, number>;
    recommendations: string[];
  } {
    const expectedCoinsPerPlayer = this.estimateExpectedCoins(
      avgGamesPerPlayer,
      avgWinRate,
    );
    const actualCoinsPerPlayer = totalCoins / totalPlayers;
    const coinRatio = actualCoinsPerPlayer / expectedCoinsPerPlayer;

    const expectedGemsPerPlayer = Math.floor(avgGamesPerPlayer * 0.5);
    const actualGemsPerPlayer = totalGems / totalPlayers;
    const gemRatio = actualGemsPerPlayer / expectedGemsPerPlayer;

    let status: "healthy" | "inflation" | "deflation" | "critical" = "healthy";
    const recommendations: string[] = [];

    if (coinRatio > 1.5) {
      status = "inflation";
      recommendations.push("Consider increasing item prices");
      recommendations.push("Reduce reward multipliers");
    } else if (coinRatio < 0.7) {
      status = "deflation";
      recommendations.push("Consider decreasing item prices");
      recommendations.push("Increase reward multipliers");
    }

    if (gemRatio > 2.0 || coinRatio > 2.0) {
      status = "critical";
      recommendations.push("Immediate investigation required");
    }

    return {
      status,
      metrics: {
        coinRatio,
        gemRatio,
        expectedCoinsPerPlayer,
        actualCoinsPerPlayer,
        expectedGemsPerPlayer,
        actualGemsPerPlayer,
      },
      recommendations,
    };
  }

  getConfig(): EconomyConfig {
    return { ...this.config };
  }

  updateConfig(newConfig: Partial<EconomyConfig>): void {
    this.config = { ...this.config, ...newConfig };
  }
}

export const createEconomyBalancer = (
  config?: Partial<EconomyConfig>,
): EconomyBalancer => {
  return new EconomyBalancer(config);
};
