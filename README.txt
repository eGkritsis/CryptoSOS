CryptoSOS Smart Contract
========================

Overview
--------
CryptoSOS is a decentralized implementation of the classic "SOS" game, deployed on the Ethereum blockchain. It allows two players to participate in a competitive game where the winner receives a substantial Ether prize, while CryptoSOS retains a small service fee. The contract handles ties, inactivity, and includes robust mechanisms for fair gameplay and security.

Features
--------
1. **Game Mechanics**:
   - Two players take turns placing 'S' or 'O' on a 3x3 grid.
   - The game ends when one player forms "SOS" horizontally, vertically, or diagonally.
   - If the board fills up with no "SOS," the game ends in a tie.

2. **Participation and Rewards**:
   - Entry fee: 1 Ether per player.
   - Winner receives 1.8 Ether. In a tie, both players are refunded 0.95 Ether each.
   - CryptoSOS retains 0.2 Ether on wins and 1 Ether in ties.

3. **Timeout Mechanism**:
   - A player can claim victory if their opponent delays their move for more than 1 minute.
   - If neither player acts for 5 minutes, the owner can declare the game a tie.

4. **Profit Management**:
   - The contract owner can withdraw accumulated profits while retaining sufficient reserves for ongoing games.

5. **Transparency**:
   - Game states, moves, and results are logged via events and accessible through public functions.

Functions and Usage
-------------------
1. **Game Initialization**:
   - `join()`: Allows players to join a game by paying the entry fee. 
     - If no opponent joins within 2 minutes, the first player can cancel their participation and receive a refund.

2. **Gameplay**:
   - `placeS(uint8 square)`: Place an "S" in the specified square (1-9).
   - `placeO(uint8 square)`: Place an "O" in the specified square (1-9).
   - `getGameState()`: Returns the current state of the board as a string.

3. **Timeouts**:
   - `tooslow()`: Can be called by players after 1 minute of opponent inactivity or by the owner after 5 minutes of inactivity to end the game.

4. **Owner-Specific**:
   - `sweepProfit(uint amountInWei)`: Allows the owner to withdraw retained profits, ensuring a reserve for active games.

Events
------
1. **StartGame(address player1, address player2)**: Logs the start of a new game.
2. **Move(address player, uint8 square, uint8 moveType)**: Logs each move made by a player (moveType: 1 = S, 2 = O).
3. **Winner(address player)**: Indicates the winning player.
4. **Tie(address player1, address player2)**: Indicates a tie between two players.

Security Measures
-----------------
1. **Gas Optimization**:
   - State variables are cached locally in functions to reduce gas usage.
   - Minimal use of string manipulations.

2. **Reentrancy Protection**:
   - The Checks-Effects-Interactions pattern is used to ensure state updates before external calls.

3. **Input Validation**:
   - Thorough validation of player inputs (e.g., square range, turn checks).
   - Detailed error messages are provided for invalid actions.

4. **Fairness**:
   - Players cannot join a game against themselves.
   - Timeout mechanisms prevent prolonged inactivity or stalling.

Potential Attacks and Mitigations
---------------------------------
1. **Reentrancy**:
   - Resetting the game state before Ether transfers prevents reentrancy attacks.

2. **DoS with High Gas**:
   - Fixed-size arrays and efficient data handling minimize the risk of gas-related denial-of-service attacks.

3. **Contract Balance Draining**:
   - Withdrawal by the owner is limited by ensuring a minimum balance for prize payouts.

Deployment Instructions
-----------------------
1. Deploy the contract using a suitable Ethereum wallet or development environment (e.g., Remix, Hardhat).
2. Ensure sufficient gas for deployment (recommended: 2,000,000 gas).
3. Fund the contract to ensure reserves for prizes.

