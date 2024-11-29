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
        require(block.timestamp >= gameStartTime + 2 minutes, "Cannot cancel yet");
        require(msg.sender == player1 && player2 == address(0), "Cannot cancel");
        payable(player1).transfer(entryFee);
        resetGame();
    }

    function tooslow() external {
    require(gameActive, "No active game");
    
    // Check if called by a player or the owner
    if (msg.sender == owner) {
        // Owner can terminate after 5 minutes of inactivity
        require(block.timestamp >= lastMoveTime + 5 minutes, "Game timeout not reached for owner");
        
        // Consider this a tie
        _endGame(address(0), 0 ether, 0 ether); // No winner; prizes handled inside _endGame
        emit Tie(player1, player2);
    } else {
        // Ensure only players can call during regular game activity
        require(msg.sender == player1 || msg.sender == player2, "Only players can call this");
        require(block.timestamp >= lastMoveTime + 1 minutes, "Move timeout not reached");

        // Determine the winner based on the turn
        address winner = (turn == 1) ? player2 : player1; // Opponent wins due to timeout
        _endGame(winner, 1.5 ether, 0.5 ether);
        emit Winner(winner);
    }
}

    function sweepProfit(uint amountInWei) external onlyOwner {
    // Ensure the requested amount is valid
    require(amountInWei > 0, "Amount must be greater than zero");
    require(address(this).balance >= amountInWei, "Insufficient contract balance");

    // Attempt to send the requested amount to the owner
    (bool success, ) = payable(owner).call{value: amountInWei}("");
    require(success, "Transfer to owner failed");
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
            _endGame(msg.sender, prizeWinner, 0.2 ether);
        } else if (!_hasEmptySquares()) {
            emit Tie(player1, player2);
            _endGame(address(0), prizeTie, prizeTie); // Tie logic
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


    function _endGame(address winner, uint winnerPrize, uint /*contractShare*/) private {
        gameActive = false;

        if (winner != address(0)) {
            payable(winner).transfer(winnerPrize);
        } else {
            payable(player1).transfer(prizeTie);
            payable(player2).transfer(prizeTie);
        }

        resetGame();
    }

    function resetGame() private {
        player1 = address(0);
        player2 = address(0);
        board = "---------";
        gameActive = false;
    }
}
