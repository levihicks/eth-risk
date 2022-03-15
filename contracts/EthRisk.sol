// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthRisk {
    struct Game {
        uint whoseTurn; // id of player who has the current turn
    }

    struct Territory {
        uint id; // id of the territory
        uint ownerId; // id of the player who owns the territory
        uint troopCount; // number of troops in the territory
    }

    uint[][] public gameMap; // gameMap[territoryId] == array of territory's neighbors
    Game[] public games; // array of games played or in-play

    /** @dev Constructs the EthRisk contract.
     *  @param _gameMap The map represented by each territory's neighbors.
     */
    constructor(uint[][] memory _gameMap) {
        gameMap = _gameMap;
    }
}