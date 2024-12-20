# README: CryptoSOS and MultiSOS Smart Contracts

This document describes the implementation details, design choices, and security considerations of the **CryptoSOS** and **MultiSOS** smart contracts. These contracts implement the SOS game on the Ethereum blockchain with features to handle single and multiple simultaneous games, focusing on security, gas optimization, and player fairness.

---

## Authors

This project was developed by:

- **Evgenios Gkritsis**
  - StudentID: f3312306
  - Contact: evgeniosgkritsis@gmail.com

- **Ilias Panagopoulos**
  - StudentID: f3312409
  - Contact: il.panagopoulos@icloud.com

---

## CryptoSOS.sol

### Overview
The **CryptoSOS** contract supports a single game of SOS at a time. Players join by paying an entry fee of 1 ether. The winner receives 1.8 ether, and in the event of a tie, each player gets 0.95 ether. The owner can sweep profits while maintaining a minimum reserve to ensure payouts.

### Key Features
- **Turn-based Play:** Players alternate moves based on whose turn it is.
- **Automatic Timeout:** Mechanisms for declaring a player too slow or resolving games after inactivity.
- **Prizes:** Automated payouts to winners or ties.

### Security Features
- **Reentrancy Prevention:** State updates are performed before external calls to prevent reentrancy attacks.
- **Strict Access Control:** Only the game owner or players can perform sensitive actions.
- **Timeout Mechanisms:** Players and the owner can terminate inactive games, ensuring the contract doesn’t lock funds indefinitely.
- **Minimum Balance Reserve:** Ensures there are enough funds for payouts even when the owner sweeps profits.

### Gas Optimization
- **Efficient State Updates:** Game state variables are cached locally in memory before updates, reducing redundant storage reads.
- **Compact Board Representation:** The 9-character board string minimizes storage and simplifies checks.

---

## MultiSOS.sol

### Overview
The **MultiSOS** contract extends CryptoSOS to handle multiple simultaneous games, allowing players to join or initiate games dynamically. It scales the SOS experience to accommodate more users without deploying separate contracts for each game.

### Key Features
- **Dynamic Game Creation:** Players join the first available game or create a new game if none is open.
- **Game Mapping:** A mapping links players to their active game IDs for quick lookup.
- **Simultaneous Games:** Supports multiple games concurrently with independent state management.
- **Automatic Timeout:** Similar to CryptoSOS, games can be ended if players or the owner detect inactivity.

### Custom Functions
- **join:** Allows players to dynamically join an available game or create a new one, optimizing player experience and gas costs.
- **tooslow:** Enables the owner or a waiting player to resolve a game when a player delays their move excessively.
- **getGameState:** Provides the full state of a player’s active game, including participants, board state, turn, and activity status.
- **sweepProfit:** Allows the owner to withdraw surplus funds while maintaining enough reserves for active games.

### Security Features
- **Game Isolation:** Each game’s state is managed independently, preventing interference between games.
- **Reentrancy Resistance:** Resetting game mappings before payouts avoids reentrancy vulnerabilities.
- **Owner Control:** The owner can monitor and resolve inactive games to maintain fairness and avoid locked funds.
- **Balance Protection:** Ensures the contract holds sufficient funds to cover payouts for all active games before allowing profit withdrawal.

### Gas Optimization
- **Shared Data Structure:** A single mapping tracks all games, reducing the need for separate contracts or additional storage.
- **Efficient Game Management:** Players are matched dynamically, minimizing the need for repetitive logic.
- **Compact State Representation:** The use of structs and minimal board encoding reduces storage costs.

---

## Difficulties and Mitigations

### Security Challenges
Handling multiple games simultaneously presented challenges in ensuring state isolation and preventing reentrancy attacks. By resetting mappings and following the checks-effects-interactions pattern, we mitigated these risks.

### Gas Considerations
Optimizing for gas was critical given Ethereum’s network fees. By using efficient state management and compact representations (e.g., 9-character board strings), we reduced gas costs for common operations like placing moves and checking game outcomes.

### Attack Mitigations
- **Reentrancy Prevention:** All external calls are made only after state changes.
- **Timeout Handling:** Timeout rules prevent malicious players from indefinitely stalling games or locking funds.
- **Reserve Management:** Profit sweeping ensures sufficient funds remain for payouts, protecting against fund exhaustion attacks.

---

## Conclusion
These contracts provide a robust, secure, and scalable implementation of the SOS game on Ethereum. **CryptoSOS** is ideal for single games, while **MultiSOS** supports a multi-game environment with dynamic matching and efficient state handling. The design ensures fairness, security, and gas efficiency for all participants.
