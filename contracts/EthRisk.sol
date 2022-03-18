// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthRisk {
    enum GameStatus {
        Deploy,
        Attack,
        Fortify
    }

    struct Territory {
        address owner; // address of the player who owns the territory
        uint troopCount; // number of troops in the territory
    }

    struct Game {
        address[] players; // players involved in game
        address whoseTurn; // address of player who has the current turn
        GameStatus status;
    }

    uint[][] public gameMap; // gameMap[territoryId] == array of territory's neighbors
    Game[] public games; // array of games played or in-play
    mapping(address => uint[]) public playersToGames; // playersToGames[player] == array of player's games
    mapping(uint => Territory[]) public territories; // territories[gameId] == array of territories for that game

    /** @dev Requires a specific game status.
     *  @param _status Required status of game.
     *  @param _gameId ID of game to check status for.
     */
    modifier onlyDuringStatus(GameStatus _status, uint _gameId) {
        require(_status == games[_gameId].status, "Wrong game status.");
        _;
    }

    /** @dev Requires a specific player's turn.
     *  @param _gameId ID of game to check status for.
     *  @param _player Address of player whose turn it should be.
     */
    modifier correctTurn(uint _gameId, address _player) {
        require(games[_gameId].whoseTurn == _player, "Not player's turn.");
        _;
    }
 
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
        games.push(Game(_players, _players[0], GameStatus.Deploy));
        newGameId = games.length - 1;
        for(uint i = 0; i < gameMap.length; i++) {
            territories[newGameId].push(Territory(_players[i < gameMap.length / 2 ? 0 : 1], 2));
        }
        for(uint i = 0; i < _players.length; i++) {
            playersToGames[_players[i]].push(newGameId);
        }
    }

    /** @dev Deploys new troops to selected territories.
     *  @param _gameId The id of the game in play.
     *  @param _troopDestinations An array of the territories to deploy troops to.
     */
    function deployTroops(
        uint _gameId, 
        uint[] memory _troopDestinations
    ) public onlyDuringStatus(GameStatus.Deploy, _gameId) correctTurn(_gameId, msg.sender) {
        require(_troopDestinations.length == gameMap.length, "Wrong _troopDestinations length.");
        uint troopsAllowed;
        uint troopsToDeploy;
        for(uint i = 0; i < gameMap.length; i++) {
            if(territories[_gameId][i].owner == msg.sender) {
                troopsAllowed += 1; 
                territories[_gameId][i].troopCount += _troopDestinations[i];
            }
            else if (_troopDestinations[i] > 0) 
                revert("Deployed in invalid territory.");
            troopsToDeploy += _troopDestinations[i];
        }
        require(troopsAllowed == troopsToDeploy, "Invalid amount of troops.");
        nextStatusPhase(_gameId);
    } 

    /** @dev Move game's status to the next phase.
     *  @param _gameId ID of the game whose status will be changed.
     */
    function nextStatusPhase(uint _gameId) private {
        GameStatus current = games[_gameId].status;
        if (current == GameStatus.Deploy)
            games[_gameId].status = GameStatus.Attack;
        else if (current == GameStatus.Attack)
            games[_gameId].status = GameStatus.Fortify;
        else if (current == GameStatus.Fortify)
            games[_gameId].status = GameStatus.Deploy;
    } 
}