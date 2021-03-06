// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

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
    mapping(uint => Territory[]) public territories; // territories[gameId] == array of territories for that game

    /** @dev Emitted when new game is created.
     *  @param _gameId ID of new game.
     *  @param _player1 Player 1.
     *  @param _player2 Player 2.
     */
    event NewGame(uint _gameId, address indexed _player1, address indexed _player2);

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
     */
    function newGame(address[] memory _players) public {
        require(_players.length == 2, "Two players required.");
        games.push(Game(_players, _players[0], GameStatus.Deploy));
        uint newGameId = games.length - 1;
        for(uint i = 0; i < gameMap.length; i++) {
            territories[newGameId].push(Territory(_players[i < gameMap.length / 2 ? 0 : 1], 2));
        }
        emit NewGame(newGameId, _players[0], _players[1]);
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
            if (_troopDestinations[i] > 0)
                troopsToDeploy += _troopDestinations[i];
        }
        require(troopsAllowed == troopsToDeploy, "Invalid amount of troops.");
        nextStatusPhase(_gameId);
    } 

    /** @dev Sets up user's attacks on enemy territories.
     *  @param _gameId ID of game in play.
     *  @param _attack An array describing the player's attacks.
     *                 In attacker territories, the value is the number 
     *                 of troops to use for battle. In enemy territories, 
     *                 the value is the index of the attacking territory,
     *                 or -1 if that territory will not be attacked.
     */
    function conductAttacks(
        uint _gameId, 
        int[] memory _attack
    ) public onlyDuringStatus(GameStatus.Attack, _gameId) correctTurn(_gameId, msg.sender) {
        require(_attack.length == gameMap.length, "Wrong _attack length."); 
        uint[] memory attackers = new uint[](gameMap.length);
        uint nonce = 0;
        for (uint i = 0; i < gameMap.length; i++) {
            if (territories[_gameId][i].owner != msg.sender && _attack[i] > -1) {
                int troopsAttacking = _attack[uint(_attack[i])];
                if (troopsAttacking <= 0) revert("Not enough attacking troops.");
                if (uint(troopsAttacking) > territories[_gameId][uint(_attack[i])].troopCount - 1)
                    revert ("Too many troops attacking.");
                if (attackers[uint(_attack[i])] != 0)
                    revert("Territory can only attack once.");
                else
                    attackers[uint(_attack[i])] = 1;
                for (uint j = 0; j < gameMap[i].length; j++) {
                    if (gameMap[i][j] == uint(_attack[i])) {
                        nonce = attack(_gameId, uint(_attack[i]), i, uint(_attack[uint(_attack[i])]), nonce);
                        break;
                    }
                    else if (j == gameMap[i].length - 1)
                        revert("Can only attack neighbor.");
                }
            }
        }
        bool gameOver = true;
        for (uint i = 0; i < gameMap.length; i++) {
            if (territories[_gameId][i].owner != msg.sender) {
                gameOver = false;
                break;
            }
        }
        if (gameOver) games[_gameId].whoseTurn = address(0);
    }

    /** @dev Conduct attack on another territory.
     *  @param _gameId ID of game in play.
     *  @param _attacker Attacking territory.
     *  @param _defender Defending territory.
     *  @param _limit Number of troops _attacker is willing to spare.
     *  @param _nonce Used for random number generation.
     *  @return currentNonce Updated nonce value.
     */
    function attack(
        uint _gameId, 
        uint _attacker, 
        uint _defender, 
        uint _limit, 
        uint _nonce
    ) private returns (uint currentNonce) {
        currentNonce = _nonce;
        uint attackingTroopsLeft = _limit;
        
        while (attackingTroopsLeft > 0 && territories[_gameId][_defender].troopCount > 0) {
            uint[] memory attackRoll = new uint[](2);
            uint[] memory defendRoll = new uint[](2);
            for(uint i = 0; i < 3; i++) {
                if (i < defendRoll.length) {
                    if (territories[_gameId][_defender].troopCount < i + 1)
                        defendRoll[i] = 0;
                    else {
                        defendRoll[i] = rollDice(currentNonce);
                        currentNonce++;
                    }
                }
                if (attackingTroopsLeft < i + 1) {
                    if (i < attackRoll.length) attackRoll[i] = 0;
                }
                else {
                    if (i < attackRoll.length)
                        attackRoll[i] = rollDice(currentNonce);
                    else {
                        uint roll = rollDice(currentNonce);
                        for (uint j = 0; j < attackRoll.length; j++) {
                            if (roll > attackRoll[j] && attackRoll[j] != 0) {
                                if (j == 0 && attackRoll[j] > attackRoll[j + 1] && attackRoll[j + 1] != 0) 
                                    attackRoll[j + 1] = attackRoll[j];
                                attackRoll[j] = roll;
                                break;
                            }
                        }
                    }
                    currentNonce++;
                }
            }
            bool defenderWins = Math.max(defendRoll[0], defendRoll[1]) >= Math.max(attackRoll[0], attackRoll[1]);
            territories[_gameId][defenderWins ? _attacker : _defender].troopCount -= 1;
            if (defenderWins) attackingTroopsLeft -= 1;
            if (territories[_gameId][defenderWins ? _attacker : _defender].troopCount == 0)
                break;
            if (Math.min(defendRoll[0], defendRoll[1]) != 0 && Math.min(attackRoll[0], attackRoll[1]) != 0) {
                defenderWins = Math.min(defendRoll[0], defendRoll[1]) >= Math.min(attackRoll[0], attackRoll[1]);
                territories[_gameId][defenderWins ? _attacker : _defender].troopCount -= 1;
                if (defenderWins) attackingTroopsLeft -= 1;
            }
        }
        if (attackingTroopsLeft > 0) { // enemy territory conquered
            territories[_gameId][_defender].owner = msg.sender;
            territories[_gameId][_attacker].troopCount -= attackingTroopsLeft;
            territories[_gameId][_defender].troopCount += attackingTroopsLeft;
        }
    }

    /** @dev Returns random number between 1 and 6
     *  @param _nonce Used for random number generation.
     *  @return result The random number. 
     */
    function rollDice(uint _nonce) public view returns (uint result) {
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, _nonce))) % 6 + 1;
    }

    /** @dev Concludes attack phase and transitions game to fortify phase.
     *  @param _gameId ID of the game in play.
     */
    function concludeAttack(uint _gameId) 
        public onlyDuringStatus(GameStatus.Attack, _gameId) correctTurn(_gameId, msg.sender) {
        if (games[_gameId].whoseTurn != address(0))
            nextStatusPhase(_gameId);
    }

    /** @dev Fortify troops from one owned territory to another
     *  @param _gameId ID of the game in play.
     *  @param _from Territory to fortify troops from.
     *  @param _to Territory to fortify troops to.
     *  @param _amount Amount of troops to fortify. 
     */
    function fortify(
        uint _gameId, 
        uint _from, 
        uint _to,
        uint _amount
    ) public onlyDuringStatus(GameStatus.Fortify, _gameId) correctTurn(_gameId, msg.sender) {
        require(_amount < territories[_gameId][_from].troopCount, "Can't fortify that many troops.");
        address fromOwner = territories[_gameId][_from].owner;
        address toOwner = territories[_gameId][_to].owner;
        require(fromOwner == toOwner && fromOwner == msg.sender, "Can't fortify in enemy land.");
        territories[_gameId][_from].troopCount -= _amount;
        territories[_gameId][_to].troopCount += _amount;
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
        else if (current == GameStatus.Fortify) {
            uint nextTurn = games[_gameId].players[0] == games[_gameId].whoseTurn ? 1 : 0;
            games[_gameId].whoseTurn = games[_gameId].players[nextTurn];
            games[_gameId].status = GameStatus.Deploy;
        }
    } 
}