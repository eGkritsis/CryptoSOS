// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSOS {
    address public owner;
    uint public entryFee = 1 ether;
    uint public prizeWinner = 1.8 ether;
    uint public prizeTie = 0.95 ether;

    struct Game {
        address player1;
        address player2;
        string board; // 9-character board ("---------" initially)
        uint8 turn; // 1 for player1, 2 for player2
        bool active;
        uint lastMoveTime;
    }

    mapping(uint => Game) public games; // Game ID to Game struct
    mapping(address => uint) public playerGame; // Player address to Game ID

    uint public nextGameId = 1;

    event StartGame(uint gameId, address indexed player1, address indexed player2);
    event Move(uint gameId, address indexed player, uint8 square, uint8 moveType); // 1=S, 2=O
    event Winner(uint gameId, address indexed player);
    event Tie(uint gameId, address indexed player1, address indexed player2);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlyPlayers(uint gameId) {
        require(
            msg.sender == games[gameId].player1 || msg.sender == games[gameId].player2,
            "Not a player in this game"
        );
        _;
    }

    modifier gameInProgress(uint gameId) {
        require(games[gameId].active, "No active game");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function join() external payable {
        require(msg.value == entryFee, "Entry fee is 1 ether");
        require(playerGame[msg.sender] == 0, "Cannot participate in multiple games");

        uint gameId = nextGameId;
        Game storage game = games[gameId];

        if (game.player1 == address(0)) {
            game.player1 = msg.sender;
            game.board = "---------";
            emit StartGame(gameId, game.player1, address(0));
        } else if (game.player2 == address(0)) {
            require(msg.sender != game.player1, "Cannot play against yourself");
            game.player2 = msg.sender;
            game.lastMoveTime = block.timestamp;
            game.active = true;
            game.turn = 1; // Player 1 starts
            playerGame[game.player1] = gameId;
            playerGame[game.player2] = gameId;
            emit StartGame(gameId, game.player1, game.player2);
            nextGameId++; // Prepare the next game slot
        } else {
            revert("Unexpected state");
        }
    }

    function placeS(uint gameId, uint8 square) external gameInProgress(gameId) onlyPlayers(gameId) {
        _makeMove(gameId, square, "S");
    }

    function placeO(uint gameId, uint8 square) external gameInProgress(gameId) onlyPlayers(gameId) {
        _makeMove(gameId, square, "O");
    }

    function getGameState(uint gameId) external view returns (string memory) {
        return games[gameId].board;
    }

    function cancel(uint gameId) external {
        Game storage game = games[gameId];
        require(!game.active, "Game has already started");
        require(msg.sender == game.player1, "Only the first player can cancel");
        require(block.timestamp >= game.lastMoveTime + 2 minutes, "Cancellation period not yet reached");

        // Refund the first player's payment
        payable(game.player1).transfer(entryFee);

        // Reset the game state
        delete games[gameId];
    }

    function tooslow(uint gameId) external {
        Game storage game = games[gameId];
        require(game.active, "No active game");
        require(
            msg.sender == owner || msg.sender == game.player1 || msg.sender == game.player2,
            "Only players or owner can call this"
        );

        if (msg.sender == owner) {
            require(block.timestamp >= game.lastMoveTime + 5 minutes, "Game timeout not reached for owner");
            emit Tie(gameId, game.player1, game.player2);
            _endGame(gameId, address(0), prizeTie);
        } else {
            require(block.timestamp >= game.lastMoveTime + 1 minutes, "Move timeout not reached");
            address winner = (game.turn == 1) ? game.player2 : game.player1;
            emit Winner(gameId, winner);
            _endGame(gameId, winner, prizeWinner);
        }
    }

    function _makeMove(uint gameId, uint8 square, string memory symbol) private {
        Game storage game = games[gameId];
        require(
            (game.turn == 1 && msg.sender == game.player1) || (game.turn == 2 && msg.sender == game.player2),
            "Not your turn"
        );
        require(square >= 1 && square <= 9, "Invalid square");
        require(bytes(game.board)[square - 1] == "-", "Square already occupied");

        bytes memory b = bytes(game.board);
        b[square - 1] = bytes(symbol)[0];
        game.board = string(b);

        emit Move(gameId, msg.sender, square, keccak256(bytes(symbol)) == keccak256(bytes("S")) ? 1 : 2);

        if (_checkWin(game.board)) {
            emit Winner(gameId, msg.sender);
            _endGame(gameId, msg.sender, prizeWinner);
        } else if (!_hasEmptySquares(game.board)) {
            emit Tie(gameId, game.player1, game.player2);
            _endGame(gameId, address(0), prizeTie);
        } else {
            game.lastMoveTime = block.timestamp;
            game.turn = game.turn == 1 ? 2 : 1; // Switch turn
        }
    }

    function _checkWin(string memory board) private pure returns (bool) {
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

    function _hasEmptySquares(string memory board) private pure returns (bool) {
        bytes memory b = bytes(board);
        for (uint8 i = 0; i < b.length; i++) {
            if (b[i] == "-") {
                return true; // Found an empty square
            }
        }
        return false; // No empty squares
    }

    function _endGame(uint gameId, address winner, uint winnerPrize) private {
        Game storage game = games[gameId];
        game.active = false;

        delete playerGame[game.player1];
        delete playerGame[game.player2];

        if (winner != address(0)) {
            payable(winner).transfer(winnerPrize);
        } else {
            payable(game.player1).transfer(prizeTie);
            payable(game.player2).transfer(prizeTie);
        }

        delete games[gameId];
    }
}
