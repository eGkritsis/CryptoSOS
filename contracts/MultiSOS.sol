// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSOS {
    struct Game {
        address player1;
        address player2;
        string board; // 9-character board ("---------")
        uint8 turn; // 1 for player1, 2 for player2
        uint lastMoveTime;
        bool gameActive;
    }

    uint constant entryFee = 1 ether;
    uint constant prizeWinner = 1.8 ether;
    uint constant prizeTie = 0.95 ether;
    uint public gameCounter;
    uint public activeGameCount;
    address public owner;

    mapping(uint => Game) public games;
    mapping(address => uint) public playerGameId; // Maps a player to their active game ID (0 if none)

    event StartGame(uint indexed gameId, address indexed player1, address indexed player2);
    event Move(address indexed player, uint8 square, uint8 moveType); // 1=S, 2=O
    event Winner(address indexed player);
    event Tie(address indexed player1, address indexed player2);
    event ProfitSwept(uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier inActiveGame() {
        uint gameId = playerGameId[msg.sender];
        require(gameId != 0, "You are not in an active game");
        require(games[gameId].gameActive, "Game is no longer active");
        _;
    }

    modifier nonReentrant() {
        require(!_entered, "Reentrancy detected");
        _entered = true;
        _;
        _entered = false;
    }

    bool private _entered;

    constructor() {
        owner = msg.sender;
        activeGameCount = 0;
    }

    function join() external payable {
        require(msg.value == entryFee, "Entry fee is 1 ether");
        require(playerGameId[msg.sender] == 0, "Already in an active game");

        for (uint i = 1; i <= gameCounter; i++) {
            if (games[i].gameActive && games[i].player2 == address(0)) {
                games[i].player2 = msg.sender;
                games[i].turn = 1;
                games[i].lastMoveTime = block.timestamp;

                playerGameId[msg.sender] = i;
                playerGameId[games[i].player1] = i;

                emit StartGame(i, games[i].player1, msg.sender);
                return;
            }
        }

        gameCounter++;
        games[gameCounter] = Game({
            player1: msg.sender,
            player2: address(0),
            board: "---------",
            turn: 0,
            lastMoveTime: block.timestamp,
            gameActive: true
        });

        activeGameCount++;
        playerGameId[msg.sender] = gameCounter;
        emit StartGame(gameCounter, msg.sender, address(0));
    }

    function placeS(uint8 square) external inActiveGame {
        _makeMove(square, "S");
    }

    function placeO(uint8 square) external inActiveGame {
        _makeMove(square, "O");
    }

    function tooslow() external nonReentrant {
        uint gameId = playerGameId[msg.sender];
        require(gameId != 0, "You are not in an active game");

        Game storage game = games[gameId];
        require(game.gameActive, "Game is no longer active");

        address waitingPlayer = (game.turn == 1) ? game.player2 : game.player1;
        require(msg.sender == waitingPlayer, "It is not your turn to call tooSlow");

        if (msg.sender == owner) {
            // Owner can call tooslow if neither player has played for 5 minutes
            require(block.timestamp >= game.lastMoveTime + 5 minutes, "Owner timeout not reached");

            // End the game as a tie
            _endGame(gameId, address(0), prizeTie);
            emit Tie(game.player1, game.player2);
        } else {
            // Player can call tooSlow after 1 minute of inactivity
            require(block.timestamp >= game.lastMoveTime + 1 minutes, "Move timeout not reached");

            // Determine the winner based on whose turn it is (opponent wins)
            address winner = (game.turn == 1) ? game.player2 : game.player1;

            // End the game, pay the winner 1.5 ether, and keep 0.5 ether for the contract
            _endGame(gameId, winner, prizeWinner);
            emit Winner(winner);
        }
    }

    function getGameState() external view inActiveGame returns (
        address player1,
        address player2,
        string memory board,
        uint8 turn,
        bool isActive
    ) {
        uint gameId = playerGameId[msg.sender];
        Game memory game = games[gameId];

        return (
            game.player1,
            game.player2,
            game.board,
            game.turn,
            game.gameActive
        );
    }

    function sweepProfit(uint amountInWei) external nonReentrant onlyOwner {
        require(amountInWei > 0, "Amount must be greater than zero");

        uint minReserve = activeGameCount * 1.9 ether;
        require(address(this).balance >= amountInWei + minReserve, "Insufficient balance for prizes");

        (bool success, ) = owner.call{value: amountInWei}("");
        require(success, "Transfer failed");

        emit ProfitSwept(amountInWei);
    }

    function cancel() external nonReentrant {
        uint gameId = playerGameId[msg.sender];
        require(gameId != 0, "You are not in an active game");

        Game storage game = games[gameId];
        require(game.player2 == address(0), "Game has already started");
        
        // Ensure that the game has been active for less than 2 minutes
        require(block.timestamp < game.lastMoveTime + 2 minutes, "Cancel timeout exceeded");

        // Reset the game state
        resetGame(gameId);

        // Refund the player the entry fee
        payable(msg.sender).transfer(entryFee);
    }



    function _makeMove(uint8 square, string memory symbol) private {
        uint gameId = playerGameId[msg.sender];
        Game storage game = games[gameId];
        require(square >= 1 && square <= 9, "Invalid square");
        require(bytes(game.board)[square - 1] == "-", "Square already occupied");

        address currentPlayer = game.turn == 1 ? game.player1 : game.player2;
        require(msg.sender == currentPlayer, "Not your turn");

        bytes memory boardBytes = bytes(game.board);
        boardBytes[square - 1] = bytes(symbol)[0];
        game.board = string(boardBytes);

        emit Move(msg.sender, square, keccak256(bytes(symbol)) == keccak256(bytes("S")) ? 1 : 2);

        if (_checkWin(game.board)) {
            _endGame(gameId, msg.sender, prizeWinner);
            emit Winner(msg.sender);
        } else if (!_hasEmptySquares(game.board)) {
            _endGame(gameId, address(0), prizeTie);
            emit Tie(game.player1, game.player2);
        } else {
            game.lastMoveTime = block.timestamp;
            game.turn = game.turn == 1 ? 2 : 1;
        }
    }

    function _checkWin(string memory board) private pure returns (bool) {
        bytes memory b = bytes(board);
        uint8[3][8] memory lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ];

        for (uint i = 0; i < 8; i++) {
            if (b[lines[i][0]] == "S" && b[lines[i][1]] == "O" && b[lines[i][2]] == "S") {
                return true;
            }
        }
        return false;
    }

    function _hasEmptySquares(string memory board) private pure returns (bool) {
        bytes memory b = bytes(board);
        for (uint i = 0; i < b.length; i++) {
            if (b[i] == "-") {
                return true;
            }
        }
        return false;
    }

    function _endGame(uint gameId, address winner, uint prize) private {
        Game storage game = games[gameId];

        // Reset game state
        game.gameActive = false;
        activeGameCount--;

        playerGameId[game.player1] = 0;
        playerGameId[game.player2] = 0;

        // Pay the winner if there is one, otherwise split the tie prize
        if (winner != address(0)) {
            // Only pay the winner
            (bool success, ) = winner.call{value: prize}("");
            require(success, "Winner payout failed");
        } else {
            // In case of a tie, pay both players if they exist
            if (game.player1 != address(0)) {
                (bool success1, ) = game.player1.call{value: prizeTie}("");
                require(success1, "Player1 tie payout failed");
            }

            if (game.player2 != address(0)) {
                (bool success2, ) = game.player2.call{value: prizeTie}("");
                require(success2, "Player2 tie payout failed");
            }
        }

        // Reset game details after the game ends
        resetGame(gameId);
    }

    function resetGame(uint gameId) private {
        Game storage game = games[gameId];
        address player1 = game.player1;

        game.player1 = address(0);
        game.player2 = address(0);
        game.board = "---------";
        game.turn = 0;
        game.lastMoveTime = 0;
        game.gameActive = false;

        if (player1 != address(0)) {
            playerGameId[player1] = 0;
        }
    }
}
