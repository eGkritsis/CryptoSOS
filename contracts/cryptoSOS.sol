// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CryptoSOS {
    address public owner;
    address public player1;
    address public player2;
    uint public gameStartTime;
    uint public lastMoveTime;

    string public board; // 9-character board ("---------" initially)
    uint8 public turn; // 1 for player1, 2 for player2
    bool public gameActive;
    
    uint constant entryFee = 1 ether;
    uint constant prizeWinner = 1.8 ether;
    uint constant prizeTie = 0.95 ether;

    event StartGame(address indexed player1, address indexed player2);
    event Move(address indexed player, uint8 square, uint8 moveType); // 1=S, 2=O
    event Winner(address indexed player);
    event Tie(address indexed player1, address indexed player2);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlyPlayers() {
        require(msg.sender == player1 || msg.sender == player2, "Not a player");
        _;
    }

    modifier gameInProgress() {
        require(gameActive, "No active game");
        _;
    }

    constructor() {
        owner = msg.sender;
        board = "---------";
    }

    function join() external payable {
        require(msg.value == entryFee, "Entry fee is 1 ether");
        require(!gameActive, "Game already in progress");

        if (player1 == address(0)) {
            player1 = msg.sender;
            emit StartGame(player1, address(0));
        } else if (player2 == address(0)) {
            require(msg.sender != player1, "Cannot play against yourself");
            player2 = msg.sender;
            gameStartTime = block.timestamp;
            lastMoveTime = block.timestamp;
            gameActive = true;
            turn = 1; // Player 1 starts
            emit StartGame(player1, player2);
        } else {
            revert("Two players are already in the game");
        }
    }

    function placeS(uint8 square) external gameInProgress onlyPlayers {
        _makeMove(square, "S");
    }

    function placeO(uint8 square) external gameInProgress onlyPlayers {
        _makeMove(square, "O");
    }

    function getGameState() external view returns (string memory) {
        return board;
    }

    function cancel() external {
        require(!gameActive, "Game has already started");
        require(msg.sender == player1, "Only the first player can cancel");
        require(block.timestamp >= lastMoveTime + 2 minutes, "Cancellation period not yet reached");

        // Reset the game state first
        // Mitigating Reentrancy Attacks
        resetGame();

        // Refund the first player's payment
        payable(player1).transfer(1 ether);
    }

    function tooslow() external {
        require(gameActive, "No active game");

        if (msg.sender == owner) {
            // Owner's action: terminate the game after 5 minutes of inactivity
            require(block.timestamp >= lastMoveTime + 5 minutes, "Game timeout not reached for owner");

            // Treat this as a tie
            _endGame(address(0), 0 ether); // No winner; prizes handled in _endGame
            emit Tie(player1, player2);
        } else {
            // Player's action: declare the opponent too slow after 1 minute of delay
            require(msg.sender == player1 || msg.sender == player2, "Only players can call this");
            require(block.timestamp >= lastMoveTime + 1 minutes, "Move timeout not reached");

            // Determine the winner based on the current turn
            address winner = (turn == 1) ? player2 : player1;
            _endGame(winner, 1.5 ether); // Distribute winnings
            emit Winner(winner);
        }
    }

    function sweepProfit(uint amountInWei) external onlyOwner {
        // Ensure the requested amount is valid
        require(amountInWei > 0, "Amount must be greater than zero");

        // Calculate the minimum reserve required
        uint minReserve = 0;
        if (gameActive) {
            // If the game is active, reserve the highest possible payout
            minReserve = 1.9 ether; // Maximum needed for a tie
        }

        // Ensure there is enough balance left after withdrawal
        require(address(this).balance >= amountInWei + minReserve, "Insufficient balance for prizes");

        // Attempt to send the requested amount to the owner using transfer (safe for EOAs)
        payable(owner).transfer(amountInWei);
    }

    // Private functions
    function _makeMove(uint8 square, string memory symbol) private {
        require((turn == 1 && msg.sender == player1) || (turn == 2 && msg.sender == player2), "Not your turn");
        require(square >= 1 && square <= 9, "Invalid square");
        require(bytes(board)[square - 1] == "-", "Square already occupied");

        bytes memory b = bytes(board);
        b[square - 1] = bytes(symbol)[0];
        board = string(b);

        emit Move(msg.sender, square, keccak256(bytes(symbol)) == keccak256(bytes("S")) ? 1 : 2);

        if (_checkWin()) {
            emit Winner(msg.sender);
            _endGame(msg.sender, prizeWinner);
        } else if (!_hasEmptySquares()) {
            emit Tie(player1, player2);
            _endGame(address(0), prizeTie); // Tie logic
        } else {
            lastMoveTime = block.timestamp;
            turn = turn == 1 ? 2 : 1; // Switch turn
        }
    }

    function _checkWin() private view returns (bool) {
        bytes memory b = bytes(board);
        uint8[3][8] memory lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
            [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
            [0, 4, 8], [2, 4, 6]             // Diagonals
        ];

        for (uint8 i = 0; i < 8; i++) {
            uint8[3] memory line = lines[i];
            if (b[line[0]] == "S" && b[line[1]] == "O" && b[line[2]] == "S") {
                return true;
            }
        }
        return false;
    }

    function _hasEmptySquares() private view returns (bool) {
        bytes memory b = bytes(board);
        for (uint8 i = 0; i < b.length; i++) {
            if (b[i] == "-") {
                return true; // Found an empty square
            }
        }
        return false; // No empty squares
    }

    function _endGame(address winner, uint winnerPrize) private {
        // Cache state variables to reduce SLOAD gas costs
        address currentPlayer1 = player1;
        address currentPlayer2 = player2;
        
        // Update the state before external calls
        // Checks-Effects-Interactions pattern
        gameActive = false;

        // Reset the game state first
        resetGame();

        // Transfer funds only after state has been updated
        if (winner != address(0)) {
            payable(winner).transfer(winnerPrize);
        } else {
            payable(currentPlayer1).transfer(prizeTie);
            payable(currentPlayer2).transfer(prizeTie);
        }
    }

    function resetGame() private {
        player1 = address(0);
        player2 = address(0);
        board = "---------";
        gameActive = false;
    }
}
