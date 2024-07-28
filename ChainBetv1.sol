// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainBet {

    struct Prediction {
        address addresss;
        int price;
        uint blockTime;
    }

    uint public poolBalance;
    uint public poolReward;

    mapping(uint => Prediction) public prediction;
    mapping(uint => address) public winners;

    uint private count;
    uint internal winnersCount;

    address public owner;

    uint internal startPrediction;
    uint internal endPredictionTime;

    AggregatorV3Interface internal priceFeed;

    // EVENTS
    event UserPrediction(address indexed _user, int _price, uint _blockTime);
    event PredictionDelete(uint _predictionDelete);
    event winner(address indexed _winner);
    event withdraw(address indexed _withdrawAddress, uint _amount);
    event Deposit(uint _amount);

    // MODIFIERS
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(uint _poolReward) {
        /*  BTC / USD *** Deviation 1% *** Heartbeat 3600s */
        priceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        owner = msg.sender;

        startPrediction = block.timestamp;
        endPredictionTime = block.timestamp + 60 minutes;
        poolReward = _poolReward;
    }

    function getChainlinkDataFeed() public view returns(int) {
        (
            /* uint80 roundId,*/ ,
            int price, 
            /* uint startedAt, */,
            /* uint timeStamp, */,
            /* uint80 answeredInRound */
        ) =  priceFeed.latestRoundData();
        return price / 10**8;
    }

    function pricePrediction(int _price) external {
        require(checkBlockTime(), "When the round starts, you have the right to prediction for the first 15 minutes, please wait for the next round.");
        
        prediction[count] = Prediction(msg.sender, _price, block.timestamp);

        unchecked {
            count += 1;
        }

        emit UserPrediction(msg.sender, _price, block.timestamp);
    }

    function depositPool() external payable onlyOwner {
        require(msg.value > 0);

        unchecked {
            poolBalance += msg.value;
        }

        emit Deposit(msg.value);
    }

    function withdrawPool(address _to, uint _amount) external onlyOwner {
        require(address(this).balance > 0, "There is no money in the pool");

        unchecked {
            poolBalance -= _amount;
        }

        payable(_to).transfer(_amount);
        emit withdraw(_to, _amount);
    }

    function checkWinner() external onlyOwner {
        require(count > 0, "No predictions, winner not announced");

        int lastPrice = getChainlinkDataFeed();
        int priceRange = lastPrice / 100; // range 1%

        int priceRangeUp = lastPrice + priceRange;
        int priceRangeDown = lastPrice - priceRange;

        for (uint i = 0; i < count; i++) {
            if (prediction[i].price >= priceRangeDown && prediction[i].price <= priceRangeUp) {
                winners[winnersCount] = prediction[i].addresss;

                unchecked {
                    winnersCount += 1;
                    poolBalance -= poolReward;
                }

                payable(prediction[i].addresss).transfer(poolReward);

                emit winner(prediction[i].addresss);
            }
        }
    }
    
    function setPoolReward(uint _reward) external onlyOwner returns(uint) {
        return poolReward = _reward;
    }

    function predictionDel() external onlyOwner {
        startPrediction = block.timestamp;
        endPredictionTime = block.timestamp + 60 minutes;

        for(uint i = 0; i < count; i++) {
            prediction[i].addresss = address(0);
            prediction[i].price = 0;
            prediction[i].blockTime = 0;
        }
        
        count = 0;

        emit PredictionDelete(count);
    }

    function checkBlockTime() internal view returns(bool) {
        
        if (block.timestamp <= startPrediction + 15 minutes) {
            return true;
        }
        return false;
    }

    receive() external payable {
        revert("Only  owner can deposit money into this contract. (deposit function)");
    }

    fallback() external payable {
        revert("Only  owner can deposit money into this contract. (deposit function)");
    }

}