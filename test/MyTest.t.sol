// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./BaseTest.sol";
import "contracts/periphery/interfaces/IVoter.sol";
import "contracts/periphery/interfaces/IVotingEscrow.sol";
import "contracts/periphery/interfaces/IMinter.sol";
import "contracts/periphery/interfaces/IBribe.sol";
import "contracts/periphery/interfaces/IRouter.sol";
import "contracts/periphery/interfaces/IGauge.sol";
import "contracts/core/interfaces/ISwapFactory.sol";
import "contracts/core/interfaces/ISwapPair.sol";
import "contracts/core/interfaces/ISwapFactory.sol";

contract AbcTest is IERC721Receiver, BaseTest {

    ISwapFactory _swapFactory;
    IVoter _voter;
    IVotingEscrow _ve;
    IMinter _minter;
    IRouter _router;

    // State
    address swapGauge;

    uint DURATION = 7 days;
    uint nextPeriod = (block.timestamp + DURATION) / DURATION * DURATION;

    address alice = address(0x1);

    function setUp() public {
        deployCoins();
        deploy();
        mintStables(address(this));

        _swapFactory = ISwapFactory(swapFactory);
        _voter = IVoter(voter);
        _ve = IVotingEscrow(votingEscrow);
        _minter = IMinter(minter);
        _router = IRouter(router);

        // Mint XCAL
        uint mintAmount = 10000 * 1e18;
        mintXcal(address(this), mintAmount);
        mintXcal(alice, mintAmount);

        // Whitelist tokens
        uint fee = _voter.listing_fee();
        token.approve(address(_voter), fee * 3);
        // _ve.create_lock(fee * 3, 4 weeks);
        _voter.whitelist(address(USDC));
        _voter.whitelist(address(DAI));
        // // Create gauges
        swapGauge = _createSwapGauge(address(DAI), address(USDC), true);
        // // Create lock
        _createLock(4 weeks, 5 * 1e18);
    }

    // Should create a gauge for a swap pair
    function test_createSwapGauge() public {
        address swapPair = _createSwapPair(address(DAI), address(USDC), false);
        address swapGauge = _voter.createSwapGauge(swapPair);
        (address _token0, address _token1) = ISwapPair(swapPair).tokens();

        // Sanity checks
        address gauge = _voter.gauges(swapPair);
        assertEq(gauge, swapGauge);
        address _bribe = _voter.bribes(swapGauge);
        // 1 since already created 1 gauge in setUp()
        assertEq(swapGauge, _voter.allGauges(1));
        assertTrue(_voter.isGauge(swapGauge));
        assertTrue(_voter.isLive(swapGauge));
        assertTrue(_voter.isReward(swapGauge, _token0));
        assertTrue(_voter.isReward(swapGauge, _token1));
        assertTrue(_voter.isBribe(_bribe, _token0));
        assertTrue(_voter.isBribe(_bribe, _token1));



    }


    address[] gaugesVotesSwap;
    uint[] gaugesWeightsSwap;
    // Should vote for a swap gauge
    function test_vote_swapGauge() public {
        gaugesVotesSwap.push(swapGauge);
        uint weights = 2 * 1e18;
        gaugesWeightsSwap.push(weights);
        _voter.vote(1, gaugesVotesSwap, gaugesWeightsSwap);
        uint _votes = _voter.votes(1, swapGauge);
        uint _weights = _voter.weights(swapGauge);
        uint _usedWeights = _voter.usedWeights(1);
        uint _totalWeight = _voter.totalWeight();
        uint _lastVote = _voter.lastVote(1);
        assertTrue(_ve.voted(1));
        assertTrue(_voter.isGauge(swapGauge));
        assertEq(gaugesVotesSwap[0], swapGauge);
        assertEq(_votes, _weights);
        assertEq(_votes, _usedWeights);
        assertEq(_weights, _totalWeight);
        assertEq(_lastVote, block.timestamp);
        // Bribe check
        address _bribe = _voter.bribes(swapGauge);
        uint _bribeBalance = IBribe(_bribe).balanceOf(1);
        assertEq(_votes, _bribeBalance);
    }

    function test_my() public {
        console.log(block.timestamp);
        console.log(nextPeriod);
        console.log(block.timestamp + DURATION);
        console.log(((block.timestamp + DURATION) / DURATION) * DURATION);
    }

    // ***** INTERNAL *****

    // Add liquidity to swap DAI/USDC stable
    function _addLiquidity(address _to) public {
        uint amountA = 100_000 * 10 ** 18;
        uint amountB = 100_000 * 10 ** 6;
        DAI.approve(address(_router), amountA);
        USDC.approve(address(_router), amountB);
        _router.addLiquidity(
            address(DAI),
            address(USDC),
            true,
            100_000 * 10 ** 18,
            100_000 * 10 ** 6,
            1,
            1,
            _to,
            block.timestamp
        );
    }

    // Do `num` number of swaps in DAI/USDC stable
    function _doSwaps(uint num) public {
        route memory route1 = route(address(DAI), address(USDC), true);
        route memory route2 = route(address(USDC), address(DAI), true);
        route[] memory _route1 = new route[](1);
        _route1[0] = route1;
        route[] memory _route2 = new route[](1);
        _route2[0] = route2;
        uint daiAmount = 5000 * 10 ** 18;
        uint usdcAmount = 5000 * 10 ** 6;
        DAI.approve(address(_router), daiAmount * num);
        USDC.approve(address(_router), usdcAmount * num);
        for (uint i = 0; i < num; i++) {
            _router.swapExactTokensForTokens(
                daiAmount,
                1,
                _route1,
                address(this),
                block.timestamp
            );
            _router.swapExactTokensForTokens(
                usdcAmount,
                1,
                _route2,
                address(this),
                block.timestamp
            );
        }
    }

    // Create a swap pair
    function _createSwapPair(address tokenA, address tokenB, bool stable) internal returns(address swapPair) {
        swapPair = _swapFactory.createPair(tokenA, tokenB, stable);
        assertTrue(_swapFactory.isPair(swapPair));
    }

    function _createSwapGauge(address tokenA, address tokenB, bool stable) internal returns(address swapGauge) {
        address swapPair = _createSwapPair(tokenA, tokenB, stable);
        swapGauge = _voter.createSwapGauge(swapPair);
    }

    // Create a lock
    function _createLock(uint time, uint amount) internal {
        token.approve(address(_ve), amount);
        _ve.create_lock(amount, time);
        address owner = _ve.ownerOf(1);
        assertEq(owner, address(this));
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return 0x150b7a02;
    }
}
