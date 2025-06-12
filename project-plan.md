### **Project Plan: Botany Battle**

**Version: 1.0**  
**Date: June 12, 2025**

### **1\. Overview**

This document outlines the development plan for the "Botany Battle" iOS application. The project is broken down into five distinct phases, designed to be completed sequentially. This phased approach will ensure that foundational elements are in place before more complex features are implemented, reducing risk and simplifying the development process for a junior developer.

### **2\. Development Phases**

#### **Phase 1: Foundation & Core Data (Estimated Time: 2 Weeks)**

* **Goal:** Establish the project's backend, data structure, and basic user interface. At the end of this phase, we will have a non-interactive app that can display plant data.  
* **Key Tasks for Junior Developer:**  
  * **Task 1.1: Project Setup:**  
    * Initialize a new Xcode project for the iOS application.  
    * Set up the basic file structure and import necessary libraries.  
  * **Task 1.2: Plant Database Implementation:**  
    * Create a local or cloud-based database (e.g., Firebase Firestore, SwiftData) to store plant information.  
    * Define the data model for a "Plant" object, including fields for:  
      * commonName (String)  
      * scientificName (String)  
      * imageURLs (Array of Strings)  
      * factOrTip (String)  
      * difficulty (Enum: Easy, Medium, Hard)  
  * **Task 1.3: Populate Initial Data:**  
    * Manually add 20-30 sample plants to the database for testing purposes. Ensure a mix of difficulties and that all data fields are filled.  
  * **Task 1.4: Create a Basic Plant Viewer:**  
    * Develop a simple, single-screen UI that fetches and displays a random plant from the database.  
    * The view should show the plant's image and its common name. This will serve as a testbed for the database connection.

#### **Phase 2: User Authentication & Profiles (Estimated Time: 1.5 Weeks)**

* **Goal:** Implement user accounts and profile management. At the end of this phase, users will be able to sign up, log in, and view a basic profile screen.  
* **Key Tasks for Junior Developer:**  
  * **Task 2.1: Authentication Integration:**  
    * Integrate an authentication service (e.g., Apple Sign-In, Firebase Authentication).  
    * Create UI screens for user sign-up and login.  
  * **Task 2.2: User Data Model:**  
    * Extend the database to include a "Users" collection.  
    * Define the data model for a "User" object, including:  
      * username (String)  
      * profilePictureURL (String)  
      * winLossRatio (Number)  
      * totalWins (Number)  
      * rank (String)  
      * trophyBalance (Number)  
  * **Task 2.3: Profile Screen UI:**  
    * Create a profile screen that displays all the information from the user's data model.  
    * Allow the user to set their username and upload a profile picture.

#### **Phase 3: Core Gameplay Loop (Estimated Time: 3 Weeks)**

* **Goal:** Build the main, single-player "battle" experience. While not yet multiplayer, this phase will implement the entire round-based guessing game against a "dummy" opponent.  
* **Key Tasks for Junior Developer:**  
  * **Task 3.1: Battle UI:**  
    * Design and build the main game screen. This should include:  
      * A large view for the plant image.  
      * Four multiple-choice buttons for the answers.  
      * A score display for the player.  
      * A timer or indicator for the round.  
  * **Task 3.2: Game Logic Implementation:**  
    * Develop the logic for a 5-round game.  
    * For each round:  
      * Fetch a random plant from the database.  
      * Populate the multiple-choice buttons: one correct answer and three incorrect answers (randomly selected from other plants).  
      * Implement the scoring logic based on correct/incorrect answers.  
  * **Task 3.3: Post-Round & Results Screens:**  
    * Create the UI to display the correct answer and the "interesting fact" after each round.  
    * Build the final results screen showing the player's score and a "You Win" or "You Lose" message.  
  * **Task 3.4: Currency Awards:**  
    * Implement the logic to award "Trophies" for winning a game. Update the user's trophyBalance in the database.

#### **Phase 4: Matchmaking & Real-Time Multiplayer (Estimated Time: 4 Weeks)**

* **Goal:** Transform the single-player game into a real-time, two-player experience. This is the most complex phase and will require careful attention to real-time data synchronization.  
* **Key Tasks for Junior Developer:**  
  * **Task 4.1: Matchmaking Lobby:**  
    * Create a "Find Game" screen that puts the player into a matchmaking queue.  
    * Implement the logic to match two players from the queue. For now, matching can be random. Skill-based matching can be a future improvement.  
  * **Task 4.2: Real-Time Game State:**  
    * Create a "Battles" collection in the database to manage active games.  
    * A battle document should store:  
      * player1\_ID and player2\_ID  
      * currentRound  
      * player1\_score and player2\_score  
      * player1\_answer and player2\_answer for the current round.  
      * A list of plant IDs to be used in the battle.  
  * **Task 4.3: Real-Time Synchronization:**  
    * Use real-time listeners (e.g., Firestore's onSnapshot) to keep the game state synchronized between the two players' devices.  
    * Update the game logic to handle the multiplayer scoring rules (e.g., who answered fastest).  
  * **Task 4.4: Direct Challenges:**  
    * Implement a system where a player can generate an invite code that another player can use to join their game directly.

#### **Phase 5: Economy, Shop & Polish (Estimated Time: 2.5 Weeks)**

* **Goal:** Finalize the application by adding the in-game shop and refining the user experience.  
* **Key Tasks for Junior Developer:**  
  * **Task 5.1: Shop Data Model:**  
    * Create a "ShopItems" collection in the database.  
    * Define a data model for items, including itemName, itemType (e.g., skin, theme), price, and imageURL.  
  * **Task 5.2: Shop UI:**  
    * Build a browsable shop interface where users can see available items and their prices.  
  * **Task 5.3: Purchase Logic:**  
    * Implement the logic for a user to purchase an item. This should:  
      * Check if the user has enough "Trophies".  
      * Deduct the cost from the user's balance.  
      * Add the purchased item to a list of owned items in the user's profile.  
  * **Task 5.4: UI Polish & Bug Fixing:**  
    * Review the entire application for UI/UX inconsistencies.  
    * Add animations and transitions to make the app feel more responsive and engaging.  
    * Conduct thorough testing to find and fix bugs before release.