 

# **Software Requirements Document (SRD)**

## **Project: "Botany Battle" (Working Title)**

**Version: 1.0**

### **1\. Introduction & Vision**

#### **1.1. Project Overview**

This document outlines the requirements for a multiplayer mobile application for the iOS platform. The app is a real-time, competitive game where two players battle to identify plant species. The core loop involves identifying plants through successive rounds, earning an in-game currency for victories, and using that currency to purchase cosmetic customizations.

#### **1.2. Vision Statement**

To create a fun, educational, and competitive game that connects plant lovers and casual gamers alike. The app will test players' botanical knowledge in a fast-paced, head-to-head format, rewarding them with collectible items and the title of ultimate "plant geek."

### **2\. User Personas**

* **The Casual Gamer:** Enjoys quick, competitive mobile games. May not have deep plant knowledge but is motivated by winning, collecting items, and social competition.  
* **The Plant Enthusiast:** Has a genuine interest in botany and horticulture. Is motivated by the challenge of identifying rare and interesting plants and proving their expertise.  
* **The Social Competitor:** Plays games to connect with friends. Is motivated by leaderboards, challenging friends directly, and sharing their victories.

### **3\. Functional Requirements (Core Features)**

#### **3.1. User Account & Profile**

* Users must be able to create an account (e.g., via Apple Sign-In, Google). We only accept third-party logins, we will not be keeping our own user list.  
* User profiles will display:  
  * Username  
  * Profile Picture / Avatar  
  * Currently equipped "skin" or cosmetic items.  
  * Game statistics (Win/Loss Ratio, Total Wins, Current Rank).  
  * Balance of in-game currency.

#### **3.2. Matchmaking**

* **Skill-Based Matchmaking:** When a player looks for a random game, the system will prioritize matching them with another player of a similar skill level or rank to ensure fair competition.  
* **Direct Challenges:** Players must be able to invite friends directly to a battle, bypassing the public matchmaking queue.

#### **3.3. Core Gameplay Loop: "The Battle"**

* A battle consists of two players competing in a series of rounds.  
* **Round Start:** A high-quality image of a random plant is displayed to both players simultaneously. The plant's difficulty will be chosen based on the players' skill levels.  
* **Guessing Mechanic:** Players are presented with 4 multiple-choice options to guess the correct plant name.  
* **Scoring & Round Winner:**  
  * A player earns one point for winning a round.  
  * If one player answers correctly and the other incorrectly, the correct player wins the round.  
  * If both players answer correctly, the player who submitted their answer first wins the round.  
  * If both players answer incorrectly, no one wins the round.  
* **Post-Round Information:** After a round ends, the correct answer and an interesting fact or care tip about the plant will be displayed to both players before the next round begins.  
* **Battle End:** A battle consists of 5 rounds. The player with the most points at the end of 5 rounds is the winner.  
* **Tie-Breaker:** If scores are tied after 5 rounds, a "sudden death" tie-breaker round begins. The first player to answer correctly wins the match. If both players answer incorrectly, a new tie-breaker plant is shown until a winner is decided.  
* **Results Screen:** At the end of the battle, a summary screen will show the winner, final scores, and currency earned.

#### **3.4. Plant Database**

* The application will require a robust database of plants.  
* Each plant entry must include:  
  * Common Name  
  * Scientific Name  
  * Multiple high-quality images.  
  * An interesting fact or care tip.  
  * A difficulty rating (e.g., Easy, Medium, Hard) to be used for matchmaking.

#### **3.5. Economy: Currency & Shop**

* The game will have a single in-game currency, referred to as "Trophies" (working name).  
* **Earning Currency:** Players earn Trophies by winning rounds and battles.  
* **The Shop:** A section of the app where players can spend their Trophies to acquire all available items.  
* **Shop Items:**  
  * Cosmetic "skins" for their in-game avatar or player frame.  
  * New themes or backgrounds for the game interface.  
  * Collectible badges or titles.

### **4\. Non-Functional Requirements**

#### **4.1. Platform**

* The application will be developed exclusively for Apple's iOS platform (iPhone).

#### **4.2. Performance**

* The application must be responsive and stable, with minimal latency during real-time gameplay.  
* Matchmaking should resolve within 15 seconds.  
* Image loading must be fast to ensure a fair start to each round.

#### **4.3. User Interface (UI) & Experience (UX)**

* The design should be clean, intuitive, and visually appealing.  
* Gameplay interface must be clear and uncluttered, focusing the user's attention on the plant image and guessing options.  
* The app must be fully responsive and look great on all supported iPhone models.

### **5\. Monetization**

* The application will be entirely free to play.  
* All in-game items and currency are earned through gameplay only.  
* There will be no in-app purchases or advertisements.

*End of Version 1.0*
