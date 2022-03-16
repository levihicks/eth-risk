// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthRisk {
    struct Territory {
        address owner; // address of the player who owns the territory
        uint troopCount; // number of troops in the territory
    }

    struct Game {
        address[] players; // players involved in game
        address whoseTurn; // address of player who has the current turn
    }

    uint[][] public gameMap; // gameMap[territoryId] == array of territory's neighbors
    Game[] public games; // array of games played or in-play
    mapping(address => uint[]) public playersToGames; // playersToGames[player] == array of player's games
    mapping(uint => Territory[]) public territories; // territories[gameId] == array of territories for that game

    /** @dev Constructs the EthRisk contract.
     *  @param _gameMap The map represented by each territory's neighbors.
     */
    constructor(uint[][] memory _gameMap) {
        gameMap = _gameMap;
    }

    /** @dev Begins a new game.
     *  @param _players The two players who will play against each other.
     *  @return newGameId The id of the newly created game.
     */
    function newGame(address[] memory _players) public returns (uint newGameId) {
        require(_players.length == 2, "Two players required.");
        games.push(Game(_players, _players[0]));
        newGameId = games.length - 1;
        for(uint i = 0; i < gameMap.length; i++) {
            territories[newGameId].push(Territory(_players[i < gameMap.length / 2 ? 0 : 1], 2));
        }
        for(uint i = 0; i < _players.length; i++) {
            playersToGames[_players[i]].push(newGameId);
        }
    }
}