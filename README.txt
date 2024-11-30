# CryptoSOS Smart Contract Documentation

## Overview

The **CryptoSOS** smart contract implements the classic "SOS" game on the Ethereum blockchain. Two players can join, pay an entry fee, and play the game for a chance to win Ether. The contract ensures fair play, manages funds securely, and allows the owner to collect profits. 

---

## Features

- **Join a Game**: Players can join the game by paying 1 Ether.
- **Play the Game**: Players take turns placing an "S" or "O" on a 3x3 grid.
- **Win Conditions**: A player wins by forming the word "SOS" horizontally, vertically, or diagonally.
- **Tie Conditions**: If the board is full without a winner, it results in a tie.
- **Timeout Rules**:
  - Players can call `tooslow` if their opponent delays their move for more than 1 minute.
  - The owner can call `tooslow` to end the game as a tie if no moves are made for 5 minutes.
- **Cancellation**: The first player can cancel their participation and get a refund if no opponent joins within 2 minutes.
- **Profit Management**: The contract retains a small portion of the entry fees as profit, which the owner can withdraw.

---

## Deployment

The contract is deployed with the following configurations:

- **Constructor**: Initializes the contract with:
  - `owner`: The deploying account.
  - `board`: A 3x3 grid represented as `"---------"`.

---

## API Reference

### Modifiers

1. **`onlyOwner`**  
   Restricts access to functions for the contract owner.

2. **`onlyPlayers`**  
   Restricts access to functions for the two registered players.

3. **`gameInProgress`**  
   Ensures the game is active before allowing certain actions.

---

### Functions

#### 1. **`join()`**
- **Description**: Allows players to join the game by paying 1 Ether.
- **Conditions**:
  - A game must not already be in progress.
  - Players must not play against themselves.
  - A fee of exactly 1 Ether must be provided.
- **Events**:
  - Emits `StartGame(address player1, address player2)` when players join.

#### 2. **`placeS(uint8 square)`**
- **Description**: Allows the current player to place an "S" on the grid.
- **Conditions**:
  - The game must be active.
  - The caller must be one of the registered players.
  - It must be the caller’s turn.
  - The square must be within range (1–9) and unoccupied.
- **Events**:
  - Emits `Move(address player, uint8 square, uint8 moveType)`.

#### 3. **`placeO(uint8 square)`**
- **Description**: Allows the current player to place an "O" on the grid.  
- **Same Conditions and Events** as `placeS`.

#### 4. **`getGameState()`**
- **Description**: Returns the current state of the game board.

#### 5. **`cancel()`**
- **Description**: Allows the first player to cancel and receive a refund if no opponent joins within 2 minutes.
- **Conditions**:
  - Only the first player can call this.
  - The game must not have started.
  - The timeout period (2 minutes) must have elapsed.

#### 6. **`tooslow()`**
- **Description**: Handles cases where a player or both players fail to act within the required time:
  - **For Players**: If an opponent delays for more than 1 minute, the caller is declared the winner.
  - **For Owner**: If no moves are made for 5 minutes, the owner can declare a tie.
- **Events**:
  - Emits `Winner(address player)` if a player wins.
  - Emits `Tie(address player1, address player2)` if it’s a tie.

#### 7. **`sweepProfit(uint amountInWei)`**
- **Description**: Allows the owner to withdraw profits accumulated by the contract.
- **Conditions**:
  - The amount must not exceed the contract balance.
  - Ensures there is enough Ether left to pay potential winners or refunds.

---

### Private/Internal Functions

#### 1. **`_makeMove(uint8 square, string memory symbol)`**
- **Description**: Handles the logic for placing a symbol on the board, switching turns, and checking for wins or ties.

#### 2. **`_checkWin()`**
- **Description**: Checks if the current board state satisfies any of the win conditions.

#### 3. **`_hasEmptySquares()`**
- **Description**: Checks if there are empty squares on the board.

#### 4. **`_endGame(address winner, uint winnerPrize, uint /*contractShare*/)`**
- **Description**: Handles game termination by distributing prizes and resetting the game state.

#### 5. **`resetGame()`**
- **Description**: Resets the game state for a new game.

---

## Events

- **`StartGame(address indexed player1, address indexed player2)`**  
  Emitted when a new game starts.

- **`Move(address indexed player, uint8 square, uint8 moveType)`**  
  Emitted after every move.

- **`Winner(address indexed player)`**  
  Emitted when a player wins.

- **`Tie(address indexed player1, address indexed player2)`**  
  Emitted when the game ends in a tie.

---

## Security Features

1. **Access Control**: 
   - Functions are restricted using modifiers (`onlyOwner`, `onlyPlayers`).
   
2. **Reentrancy Protection**:
   - Use of direct `transfer` ensures minimal reentrancy risk.
   
3. **Input Validation**:
   - Strict checks on parameters (e.g., valid squares, entry fees).
   
4. **Timeout Handling**:
   - Implements time-based rules to prevent stalled games.

5. **Funds Management**:
   - Ensures the contract retains sufficient funds to pay prizes or refunds.

## Design Considerations

### API Design: Public, External, and Internal Methods
The contract is designed with a clear API structure:

- **Public/External Methods**:
  - Methods like `join`, `placeS`, `placeO`, `cancel`, and `tooslow` are exposed to users and declared as either `public` or `external`.
  - These methods form the **user-facing API** and are explicitly designed for player interaction or contract management.
  - **Rationale**: These functions are intended to interact with external callers (players, owner). Declaring them `external` minimizes gas costs as it avoids unnecessary copying of calldata into memory when called externally.

- **Private/Internal Methods**:
  - Methods like `_makeMove`, `_checkWin`, `_hasEmptySquares`, `_endGame`, and `resetGame` are declared as `private` or `internal`.
  - **Rationale**: These functions encapsulate logic and are not directly callable by users, ensuring modularity and protecting sensitive operations like game resetting and balance distribution.

By restricting access to internal functions, the contract minimizes the attack surface and ensures key operations are only performed within controlled contexts.

---

### Input Validation
The contract implements robust input validation with clear error messages using `require` and `revert` statements. Examples include:

- **Game State Checks**: Ensuring a game is active before allowing moves using the `gameInProgress` modifier.
- **Player Checks**: Verifying that only registered players can make moves or invoke time-sensitive methods using the `onlyPlayers` modifier.
- **Input Range Checks**: Validating that squares selected for moves fall within the range of 1–9 and are not already occupied.

By providing clear and concise error messages, the contract ensures transparency and ease of debugging for players and developers.

---

### Gas Optimization
The contract is optimized for gas efficiency in both deployment and execution:

1. **Compact State Variables**: State variables are used efficiently, and immutable variables like `entryFee` are set as constants to save gas.
2. **Avoiding Loops Where Possible**:
   - The `_hasEmptySquares` function is linear but runs only when necessary to determine game completion.
   - Game logic avoids nested loops, and the `_checkWin` function operates on predefined winning line combinations.
3. **Memory vs Storage**:
   - Storage reads/writes are minimized in favor of memory where appropriate (e.g., the board manipulation in `_makeMove`).
4. **Efficient Data Structures**:
   - The game board is stored as a single string for compactness and simplified operations.

---

### Security Measures
The contract includes various safeguards against potential attacks:

1. **Access Control**:
   - The `onlyOwner` and `onlyPlayers` modifiers ensure that critical functions are restricted to authorized users.
2. **Reentrancy Protection**:
   - Although not explicitly using the `Checks-Effects-Interactions` pattern due to straightforward logic, state variables like `gameActive` are updated before external calls.
3. **Preventing Unintended Invocation**:
   - Functions like `cancel` are restricted to the first player only before the game starts.
   - The `tooslow` function enforces strict timeouts and role-based behavior (players vs. owner).
4. **Input Sanitization**:
   - Board state and player inputs are validated at every step to prevent invalid or malicious data.

---

### Comments and Code Readability
The code is extensively commented to improve readability and maintainability:
- Each function has a brief description of its purpose.
- Critical sections, such as game-ending conditions and prize distribution logic, include detailed explanations.
- Additional comments are provided where specific design decisions (e.g., gas optimization or attack prevention) are implemented intentionally.

By ensuring concise and clear code with meaningful comments, the contract is both easier to audit and more secure against potential vulnerabilities.
