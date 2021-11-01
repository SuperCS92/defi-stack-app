// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenFarm is Ownable {

    string public name = "Dapp Token Farm";
    IERC20 public dappToken;

    address[] public s_allowedTokens;
    address[] public s_stakers;

    //tokenaddress -> owner -> balance
    mapping(address => mapping(address => uint256)) s_stakingBalance;
    mapping(address => uint256) public s_uniqueTokensStaked;
    mapping(address => address) public s_tokenPriceFeedMapping;
    
    constructor(address _dappTokensAdrress) public {
        dappToken= IERC20(_dappTokensAdrress);
    }

    function addAllowedTokens(address _token) public onlyOwner{
        s_allowedTokens.push(_token);
    }

    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        s_tokenPriceFeedMapping[_token] = _priceFeed;
    }

    //stakeTokens
    //unstakeTokens
    //issueTokens
    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount> 0, "Amount cannot be 0");
        require(tokenIsAllowed(_token), "Token isn't currently allowed");
        updateUniqueTokensStaked(msg.sender, _token);

        //transfer the token from them to "us"
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        s_stakingBalance[_token][msg.sender] = s_stakingBalance[_token][msg.sender] + _amount;

        if(s_uniqueTokensStaked[msg.sender] == 1) {
            s_stakers.push(msg.sender);
        }
    }

    ///TO DO ---> ADD PARAMETER _AMOUNT TO LET THE USER CHOOSE HOW MUCH HE WANT TO WITHDRAW
    function unstakeTokens(address _token) public {
        //Fetch staking balance
        uint256 balance = s_stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        s_stakingBalance[_token][msg.sender] = 0;
        s_uniqueTokensStaked[msg.sender] = s_uniqueTokensStaked[ msg.sender] - 1;
    }

    function getUserTotalValue(address _user) public view returns (uint256){
        uint256 totalValue = 0;

        if(s_uniqueTokensStaked[_user] > 0){
            for( uint256 allowedTokensIndex = 0;
                allowedTokensIndex < s_allowedTokens.length;
                allowedTokensIndex++)

                totalValue = totalValue + getUserTokenStakingBalanceEthValue(_user, s_allowedTokens[allowedTokensIndex] );
        }

        return totalValue;
    }

    function tokenIsAllowed(address _token) public view returns(bool){
        for( uint256 allowedTokensIndex = 0;
            allowedTokensIndex < s_allowedTokens.length;
            allowedTokensIndex++) {
                if(s_allowedTokens[allowedTokensIndex] == _token) return true;
            }

            return false;
    }

    function updateUniqueTokensStaked(address _user, address _token) internal {
        if(s_stakingBalance[_token][_user] <=0){
            s_uniqueTokensStaked[_user] = s_uniqueTokensStaked[_user] + 1 ;
        }
    }    

    //TO DO => A MORE GAS EFFICIENT WAY TO ISSUE ALL TOKENS
    //Issuing tokens
    function issueTokens() public onlyOwner {
        //Issue tokens to all stakers
        for( 
            uint256 stakersIndex = 0;
            stakersIndex < s_stakers.length;
            stakersIndex++
        ){
            address recipient = s_stakers[stakersIndex];

            dappToken.transfer(recipient, getUserTotalValue(recipient));
        }
    }

    function getUserTokenStakingBalanceEthValue(address _user, address token) public view returns (uint256) {
        if(s_uniqueTokensStaked[_user] <= 0){
            return 0;
        }

        (uint256 price, uint8 decimals) = getTokenEthPrice(token);

        return (s_stakingBalance[token][_user] * price ) / ( 10**uint256(decimals) );
    }

    function getTokenEthPrice(address _token) public view returns (uint256, uint8){
        address priceFeedAddress = s_tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);

        (
            uint80 roundID,
            int256  price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        return (uint256(price), priceFeed.decimals());
    }

}

