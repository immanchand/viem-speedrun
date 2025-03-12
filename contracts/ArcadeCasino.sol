// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Arcade Game Casino
/// @author Kanta Incorporated
/// @notice Simple games meets a betting casino.
///         Players pay a small small amount for each game. 
///         The Player with the high score for 24 hours gets to keep all the ticket money from previous players
/// @dev My first project so its full of solidity mistakes. 
contract ArcadeCasino {
    address immutable OWNER;
    address immutable GAME_MASTER;
    //each ticket price is 0.0001 ETH / ~$0.2 / 100000 gwei
    uint256 public constant GAME_PRICE_WEI = 0.0001 ether; 
    uint256 public devFund;
    // struct to hold all details of a game
    struct Game {
        // the block.timestamp at which the game will end
        // this is incremented 24 from current timestamp everytime a new high score is set
        uint256 endTime;
        // the current high score of any player of this game
        uint256 highScore;
        // the current player that holds the high score in this game
        address leader;
        // the amount of money in this game that can be won
        // it is incremented everytime a new player starts playing this game
        // the ticket price of each game is added to the pot on every start of game
        uint256 pot;
    }
    //mapping of a game id to all the details of that game (struct)
    mapping (uint256 => Game) games;
    //mapping the address of the players and how many tickets they have
    mapping (address => uint256) tickets;
    //mapping the address of the player and which game they are currently playing
    //this is to make sure that an endGame is only called after a startGame for the same gameId exists
    mapping (address => uint256) gamePlay;

    event GameTicketsMinted(address indexed player, uint256 tickets);
    event GameCreate(uint256 indexed gameId, uint256 endTime);
    event GameStart(address indexed player, uint256 indexed gameId);
    event GameEnd(address indexed player, uint256 indexed gameId, uint256 score);
    event GameEndHighScore(address indexed player, uint256 indexed gameId, uint256 score, uint256 endTime);
    event GameWinnerWithdraw(address indexed player, uint256 winnings);

    //modifier that ensures that certain functions to be only called by the owner
    modifier onlyOwner() {
        require(msg.sender == OWNER, "This function is restricted to the Owner");
        _;
    }

    //modifier that ensures that certain functions to be only called by the gameMaster
    modifier onlyGameMaster() {
        require(msg.sender == GAME_MASTER, "This function is restricted to the Game Master");
        _;
    }

    constructor(address _gameMaster) {
        //initialize the owner and the gameMaster frontend
        require(_gameMaster != address(0));
        OWNER = msg.sender;
        GAME_MASTER = _gameMaster;
    }

    //incase someone sends money directly to the contract, keep it in devFund
    receive() external payable {
        devFund += msg.value;
    }
    fallback() external payable {
        devFund += msg.value;
    }

    /// @notice Mint tickets for game play
    /// @dev emits a GameTicketsMinted event
    /// @dev reverts if the minimum ticket price is not sent
    /// @return mintedTickets the number of minted tickets in this transaction
    function mintTickets() external payable returns(uint256) {
        uint256 _GAME_PRICE_WEI = GAME_PRICE_WEI;
        //pay at least a minimum of 1 ticket
        require(msg.value >= _GAME_PRICE_WEI, "Please pay for at least 1 ticket");
        //the number of minted tickets is whole number division of money sent over ticket price
        uint256 mintedTickets = msg.value / _GAME_PRICE_WEI;
        //add the minted tickets to the players existing tickets if any
        tickets[msg.sender] += mintedTickets;
        // emit the mint tickets
        emit GameTicketsMinted(msg.sender, mintedTickets);
        //return the number of minted tickets in this transaction
        return mintedTickets;
    }

    // it doesnt cost a ticket to create a game, but this can be evaluated????
    // it is expected that the player who created the game will start a game but to be evaluated ?????
    /// @notice create a new game to start with a score of zero 0
    /// @dev can only be called by the game master frontend
    /// @dev emits a GameCreate event
    /// @dev reverts if the game id is 0
    /// @dev reverts if player doesnt have tickets
    /// @dev reverts if the same gameid already exists
    /// @param _gameId The unique identifier of this game
    /// @param _player the player who requested to create a game
    /// @return success the success or failure indicator of creating a new game
    function createGame(uint256 _gameId, address _player) external onlyGameMaster returns(bool) {
        // the game id cannot be 0 because this is the default value in a mapping
        require(_gameId != 0, "Game id cannot be 0");
        // the player must have at least 1 ticket to create a game even if ticket is not deducted
        // need to evaluate if it should cost a ticket to create a new game ????
        require(tickets[_player]>=1, "Please purchase tickets first");
        require(games[_gameId].endTime == 0, "Game with this id already exists");
        // create a new game and initialze the starting values
        // game clock starts immediately to prevent long stuck games
        // games that are created but not played should expire sooner than 24 hours ????
        // the current leader is 0x0 and the high score is 0, but the endtime is set
        // Game(endtime, highscore, leader, pot)
        games[_gameId] =
            Game((block.timestamp + 1 days), 0, address(0), 0);
        //emit event
        emit GameCreate(_gameId, (block.timestamp + 1 days));
        // return true as a success indicator of creating a new game
        return true;
    }

    /// @notice Start playing a game
    /// @dev can only be called by the game master frontend
    /// @dev emits a GameStart event
    /// @dev reverts if the player doenst have any tickets to start playing
    /// @dev reverts if a game with this id hasnt been created yet
    /// @dev reverts if this game has already ended i.e. endtime has passed
    /// @dev a minted ticket is deducted from the players account for every start game
    /// @param _gameId The unique identifier of this game
    /// @param _player the player who is starting to play this game
    /// @return success the success or failure indicator of starting a new game
    function startGame(uint256 _gameId, address _player) external onlyGameMaster returns(bool) {
        uint256 ticktsOfPlayer = tickets[_player];
        uint256 _endTime = games[_gameId].endTime;
        // make sure that the player has tickets to start playing
        require(ticktsOfPlayer >= 1, "Player needs to purchase tickets");
        // make sure that the game exists
        require(_endTime != 0, "Please create this game first");
        // make sure that the existing game hasnt ended yet
        require(block.timestamp < _endTime, "The game has already ended");
        // reduce a ticket from the player first
        tickets[_player] = ticktsOfPlayer - 1;
        // set the players game play to this game id
        gamePlay[_player] = _gameId;
        // add one game ticket price to the game pot
        games[_gameId].pot += GAME_PRICE_WEI;
        // emit event
        emit GameStart(_player, _gameId);
        // return true as a success indicator that the game start is successful
        return true;
    }

    /// @notice Ending the game of the player
    /// @dev can only be called by the game master frontend
    /// @dev player must have called the startGame successfully before calling an endGame
    /// @dev if it is a high score, the player is the leader and score is saved. otherwise ignored
    /// @dev emits a GameEnd event
    /// @dev emits a GameEndHighScore event if new high score was acheived
    /// @dev reverts if this player doesnt have an active game play for this game id
    /// @dev reverts if this game has already ended i.e. endtime has passed
    /// @param _gameId The unique identifier of this game
    /// @param _player the player who is starting to play this game
    /// @param _score the score of the player at the end of the game
    /// @return success the success or failure indicator of ending a new game
    /// should this return the new game information like returnGame ???
    function endGame(uint256 _gameId, address _player, uint256 _score) external onlyGameMaster returns(bool) {
        uint256 _endTime = games[_gameId].endTime;
        // make sure that the game exists
        require(_endTime != 0, "This game does not exist or has been withdrawn");
        // make sure that this player started a game with this same id
        // this ensure that a ticket was spent at the start of this game
        // a player can only have 1 active game at a time
        require(gamePlay[_player] == _gameId, "No running game for this player");
        // make sure that the game has not ended yet
        require(block.timestamp < _endTime, "The game has already ended");
        // reset the active game play of the player
        // this is so that end game cannot be called again for the same game
        gamePlay[_player] = 0;
        //emit end game event
        emit GameEnd(_player, _gameId, _score);
        //check for high score
        //if highest score then set the score and the leader
        //extend the endtime for another 24 hours if high score
        if (_score > games[_gameId].highScore) {
            // this score is the new highscore
            games[_gameId].highScore = _score;
            // this player is the new leader
            games[_gameId].leader = _player;
            // endtime fo the game is extended by 24 hours
            // 24 hours chance for any other player to beat the highscore
            games[_gameId].endTime = block.timestamp + 1 days;
            // emit event
            emit GameEndHighScore(_player, _gameId, _score, (block.timestamp + 1 days));
        }
        // return true as an indicator that the game ended successfully
        // does not indicate anything about high score or leader
        // should the function return the game?????
        return true;
    }

    /// @notice Player who is the winner can withdraw the money
    /// @dev can only be called by the winner
    /// @dev emits a WinnerWithdraw event????
    /// @dev reverts if this game has not ended i.e. endtime hasn't passed
    /// @dev reverts if this game has already been withdrawn by winner
    /// @dev reverts if this game pot is empty (zero)
    /// @dev reverts if caller of the function is not the leader (winner)
    /// @dev the winner is the leader with the highscrore for 24 hours
    /// @dev the winnings that can be withdrawn is 98% of game pot. 2% goes to dev fund
    /// @param _gameId The unique identifier of this game
    /// @return success the success or failure indicator of withdrawal of the winnings
    function winnerWithdraw(uint256 _gameId) external returns(bool) {
        uint256 _gamePot = games[_gameId].pot;
        // make sure the game has ended already
        require(games[_gameId].endTime < block.timestamp, "Game hasn't ended yet");
        // make sure that the game pot has not been withdrawn or empty already
        // helps with rentrancy and exploits
        require(_gamePot != 0, "The game pot is empty");
        // make sure that only the leader with the highscore can withdraw
        require(msg.sender == games[_gameId].leader, "Only the winner can withdraw");
        // 2% of winnings for development/running costs
        devFund = (2 * _gamePot) / 100;
        // calculate how much the winner gets from the game pot
        uint256 winnersPot = _gamePot - devFund;
        address winner = msg.sender;
        // set the gamepot and all values to 0 so that the pot is empty and cant be withdrawn again
        // prevent reentrancy by setting to 0 before sending transaction
        // Game(endtime, highscore, leader, pot)
        games[_gameId] = Game(0,0,address(0),0);
        // send the winners pot amount to the leader's address directly
        // better than sending it to msg.sender just in case
        (bool ok, ) = address(winner).call{value: winnersPot}("");
        // check that the transfer was successful to the leader
        require(ok, "transfer failed");
        //emit event
        emit GameWinnerWithdraw(winner, winnersPot);
        // return the success flag as an indicator that the withdraw happened
        return ok;
    }

    /// @notice Owner can withdraw development fund
    /// @dev can only be called by the owner
    /// @dev reverts if caller is not the owner
    /// @dev reverts if this game has already been withdrawn by winner
    /// @return success the success or failure indicator of withdrawal of the dev fund
    function devFundWithdraw() external onlyOwner returns(bool) {
        //dev fund should not be empty
        require(devFund != 0, "Dev fund is empty");
        // additional variable to prevent rentrancy
        uint256 reEntDevFund = devFund;
        // reset the dev fund to 0 before transfering to prevent rentrancy
        // the owner shouldnt be allowed to drain the entire contract with active games
        devFund = 0;
        // send the dev fund amount to the owners address directly
        // better than sending to msg.sender
        (bool ok, ) = address(OWNER).call{value: reEntDevFund}("");
        // check that the transfer happened successfully
        require(ok, "transfer failed");
        // return the success flag as an indicator that the withdraw happened
        return ok;
    }

    //function to return the details of a specific game 
    function getGame(uint256 _gameId) external view returns(Game memory) {
        return games[_gameId];
    }

    // function to return the number of tickets that the caller has
    function getTickets() external view returns(uint256) {
        return tickets[msg.sender];
    }

    // function to return the number of tickets that a player has
    function getTickets(address _player) external view returns(uint256) {
        return tickets[_player];
    }

    // function to return the amoun in dev fund
    function getDevFund() external view returns(uint256) {
        return devFund;
    }

}
