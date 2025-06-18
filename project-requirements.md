# **Software Requirements Document (SRD)**

## **Project: "Botany Battle" (Working Title)**

**Version: 2.0**

### **1\. Introduction & Vision**

#### **1.1. Project Overview**

This document outlines the requirements for a botanical identification mobile application for the iOS platform. The app features both single-user competitions and multiplayer battles where players test their plant identification skills. The core experience includes single-user time-based challenges (Beat the Clock, Speedrun, Practice) and optional multiplayer battles between two players. Players earn in-game currency through victories and use that currency to purchase cosmetic customizations.

#### **1.2. Vision Statement**

To create a fun, educational, and competitive game that welcomes all plant lovers and casual gamers. The app provides immediate access to single-user botanical challenges while offering optional multiplayer battles for those seeking social competition. Players can test their botanical knowledge at their own pace or in competitive formats, earning rewards and achieving the title of ultimate "plant geek."

### **2\. User Personas**

* **The Casual Gamer:** Enjoys quick, competitive mobile games. Prefers immediate access without setup barriers. May not have deep plant knowledge but is motivated by personal achievement, collecting items, and beating personal bests.
* **The Plant Enthusiast:** Has a genuine interest in botany and horticulture. Values educational content and is motivated by learning new plants and proving their expertise through challenging identification tasks.
* **The Social Competitor:** Plays games to connect with friends. Is motivated by leaderboards, challenging friends directly, and sharing their victories in multiplayer battles.
* **The Solo Learner:** Wants to improve plant identification skills at their own pace. Prefers practice modes without time pressure and values educational plant facts and learning opportunities.
* **The Time-Challenged Player:** Has limited gaming time and wants quick, accessible gameplay. Values single-user modes that can be played anytime without waiting for other players or managing social features.

### **3\. Functional Requirements (Core Features)**

#### **3.1. User Account & Profile**

* **Authentication Options:**
  * **Guest Mode:** Immediate access to all single-user features without authentication
  * **Game Center (Optional):** For multiplayer features, leaderboards, and cross-device sync
* **Profile Systems:**
  * **Local Profile (Guest Mode):** Stores single-user statistics and progress locally
  * **Game Center Profile:** Full profile with multiplayer statistics and social features
* **Profile Information:**
  * Username (local or Game Center)
  * Profile Picture/Avatar
  * Currently equipped cosmetic items
  * Single-user statistics (Personal Bests, Total Games, Achievements)
  * Multiplayer statistics (Win/Loss Ratio, Rank) - Game Center only
  * Balance of in-game currency (Trophies)

#### **3.2. Single-User Game Modes**

* **Beat the Clock Mode:**
  * 60-second time limit to identify as many plants as possible
  * Progressive difficulty scaling within the time limit
  * Real-time scoring with immediate feedback
  * Personal best tracking and display
  * Trophy rewards based on performance

* **Speedrun Mode:**
  * Race to correctly identify 25 plants as quickly as possible
  * Precision timing with millisecond accuracy
  * Advanced performance rating system
  * Comprehensive statistics tracking
  * Personal best times and performance metrics

* **Practice Mode:**
  * Unlimited plant identification without time pressure
  * Visual plant images with educational content
  * Detailed results screen with learning opportunities
  * Plant facts and care tips after each identification
  * Progress tracking without competitive pressure

#### **3.3. Multiplayer Features (Optional)**

* **Skill-Based Matchmaking:** When a player looks for a random game, the system will prioritize matching them with another player of a similar skill level or rank to ensure fair competition.  
* **Direct Challenges:** Players must be able to invite friends directly to a battle, bypassing the public matchmaking queue.
* **Authentication Required:** Multiplayer features require Game Center authentication for identity verification and social features.

#### **3.4. Multiplayer Gameplay Loop: "The Battle"**

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

#### **3.5. Plant Database**

* **Primary Data Source:** The application will source its plant data directly from the **iNaturalist API**. 
* Each plant entry must include:  
  * Common Name  
  * Scientific Name  
  * Multiple high-quality images.  
  * An interesting fact or care tip.  
  * A difficulty rating (e.g., Easy, Medium, Hard) to be used for matchmaking.

#### **3.6. Economy: Currency & Shop**

* The game will have a single in-game currency, referred to as "Trophies" (working name).  
* **Earning Currency:** Players earn Trophies through multiple ways:
  * Single-user mode achievements (personal bests, high scores)
  * Completing Practice mode sessions
  * Multiplayer battle victories
  * Daily challenges and special achievements
* **The Shop:** A section of the app where players can spend their Trophies to acquire all available items.
* **Shop Items:**
  * Cosmetic "skins" for their in-game avatar or player frame
  * New themes or backgrounds for the game interface
  * Collectible badges or titles
  * Special plant fact collections
  * Achievement celebration effects

### **4\. Non-Functional Requirements**

#### **4.1. Platform**

* The application will be developed exclusively for Apple's iOS platform (iPhone).

#### **4.2. Performance**

* The application must be responsive and stable, with minimal latency during gameplay.
* **Single-User Performance:**
  * Game modes must launch within 2 seconds
  * Plant images must load within 1 second
  * Timer accuracy within 10 milliseconds for competitive modes
* **Multiplayer Performance:**
  * Matchmaking should resolve within 15 seconds
  * Real-time synchronization with minimal latency
  * Image loading must be fast to ensure fair start to each round

#### **4.3. User Interface (UI) & Experience (UX)**

* The design should be clean, intuitive, and visually appealing.  
* Gameplay interface must be clear and uncluttered, focusing the user's attention on the plant image and guessing options.  
* The app must be fully responsive and look great on all supported iPhone models.

### **5\. Monetization**

* The application will be entirely free to play.  
* All in-game items and currency are earned through gameplay only.  
* There will be no in-app purchases or advertisements.

### **6. Technical Architecture & Infrastructure**

#### **6.1. Backend Architecture**
* The application will use a monolithic architecture with the following components:
  * Express.js server with TypeScript
  * WebSocket server for real-time gameplay
  * PostgreSQL for data storage
  * Redis for caching and real-time game state
  * Simple file-based image storage (with CDN for production)
* The backend will be containerized using Docker for easy deployment

#### **6.2. Real-time Communication**
* WebSocket protocol will be used for real-time game communication
* Simple connection state management
* Basic message queuing for high-load scenarios

#### **6.3. Data Storage**
* PostgreSQL for all persistent data
* Redis for caching and real-time game state
* Simple file system for image storage in development
* CDN for image delivery in production

### **7. Security Requirements**

#### **7.1. Authentication & Authorization**
* **Dual Authentication System:**
  * **Guest Mode:** No authentication required for single-user features
  * **Game Center Integration:** Optional authentication for multiplayer and social features
* **Session Management:**
  * Local data persistence for guest mode
  * Game Center-based session management for authenticated users
  * Seamless transition between guest and authenticated modes
* **API Security:**
  * Basic rate limiting on API endpoints
  * Simple IP-based blocking for suspicious activity
  * Optional user identification for multiplayer features

#### **7.2. Data Privacy**
* GDPR compliance for all user data
* Basic data retention policies
* User data export and deletion capabilities
* Privacy policy and terms of service documentation

#### **7.3. API Security**
* HTTPS for all communications
* API key management for iNaturalist integration
* Basic input validation
* Regular security audits

### **8. Testing Requirements**

#### **8.1. Testing Strategy**
* Unit testing with Jest
* Integration testing for API endpoints
* Basic end-to-end testing
* Simple performance testing

#### **8.2. Quality Assurance**
* Basic CI/CD pipeline
* Code coverage requirements (minimum 70%)
* Regular security scanning
* User acceptance testing process

### **9. Error Handling & Edge Cases**

#### **9.1. Network Handling**
* **Offline-First Design:**
  * All single-user modes work completely offline
  * Local data storage for guest mode progress
  * Plant database caching for offline play
* **Network Resilience:**
  * Graceful handling of network disconnections during multiplayer
  * Simple reconnection logic for multiplayer features
  * Timeout handling for API calls
  * Seamless fallback to single-user modes when network unavailable

#### **9.2. API Resilience**
* Simple retry mechanism for external API calls
* Basic fallback strategies for iNaturalist API failures
* Simple data validation

### **10. Analytics & Monitoring**

#### **10.1. Performance Monitoring**
* Basic service health monitoring
* Simple performance metrics
* Error tracking
* Basic user analytics

#### **10.2. Business Analytics**
* Basic player engagement metrics
* Simple matchmaking effectiveness tracking
* Basic economy metrics
* Simple user retention analysis

### **11. Deployment & DevOps**

#### **11.1. Deployment Strategy**
* Simple deployment process
* Basic environment management (dev, production)
* Simple rollback procedures

#### **11.2. Infrastructure**
* Single cloud provider (AWS)
* Basic infrastructure setup
* Simple scaling policies
* Basic backup procedures

### **12. Game Design Details**

#### **12.1. Matchmaking System**
* Minimum player pool size: 1000 active players
* Maximum matchmaking wait time: 30 seconds
* Skill-based matchmaking algorithm
* Handling of inactive players and AFK detection

#### **12.2. Ranking System**
* ELO-based ranking system
* Seasonal rankings with rewards
* Anti-smurfing measures
* Rank decay for inactive players

### **13. Documentation Requirements**

#### **13.1. Technical Documentation**
* API documentation (OpenAPI/Swagger)
* Architecture documentation
* Deployment procedures
* Troubleshooting guides

#### **13.2. User Documentation**
* In-app tutorial
* FAQ section
* Plant identification guide
* Community guidelines

### **14. Localization & Internationalization**

#### **14.1. Language Support**
* Initial support for English
* Future support for Spanish, French, German, Swedish
* Localized plant names and descriptions
* Time zone handling

#### **14.2. Cultural Considerations**
* Region-specific plant variations
* Cultural sensitivity in plant descriptions
* Localized content moderation
* Regional event scheduling

### **15. Accessibility**

#### **15.1. Accessibility Standards**
* WCAG 2.1 AA compliance
* Screen reader support
* Keyboard navigation
* Color contrast requirements

#### **15.2. User Experience**
* **Inclusive Design:**
  * No authentication barriers for core functionality
  * Alternative input methods for all game modes
  * Adjustable text sizes throughout the app
  * Motion sensitivity options
  * Audio descriptions for plant images
* **Accessibility in Game Modes:**
  * Practice mode for pressure-free learning
  * Adjustable timer options for competitive modes
  * Visual and audio feedback for all interactions
  * Screen reader support for all UI elements

### **16. Single-User Mode Implementation Details**

#### **16.1. Core Architecture**
* **Guest Mode Support:**
  * Immediate app access without authentication
  * Local Core Data persistence for progress tracking
  * Offline-first design for all single-user features

#### **16.2. Game Mode Specifications**
* **Beat the Clock:**
  * 60-second countdown timer
  * Progressive difficulty within session
  * Score calculation based on correct answers and speed
  * Personal best tracking with date/time stamps

* **Speedrun:**
  * Fixed 25-question format
  * Millisecond-precision timing
  * Performance rating system (Bronze/Silver/Gold tiers)
  * Comprehensive statistics (average time per question, accuracy rate)

* **Practice:**
  * Unlimited questions without time pressure
  * Educational focus with plant facts and care tips
  * Visual plant images for enhanced learning
  * Progress tracking without competitive pressure

#### **16.3. Data Management**
* **Local Storage:**
  * Core Data for persistent local storage
  * Personal best records and statistics
  * User preferences and settings
  * Trophy balance and achievements

* **Optional Cloud Sync:**
  * Game Center integration for cross-device sync
  * Backup and restore functionality
  * Multiplayer profile integration

#### **16.4. User Experience Flow**
* **App Launch:**
  * Direct access to game mode selection
  * No authentication barriers
  * Optional "Connect to Game Center" prompt

* **Mode Selection:**
  * Single-user modes prominently featured
  * Multiplayer modes clearly marked as "requires connection"
  * Seamless transition between authenticated and guest modes

*End of Version 2.0* 
