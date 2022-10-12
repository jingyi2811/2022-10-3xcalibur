// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ISwapPair {
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
    function claimFees() external returns (uint, uint);
    function tokens() external view returns (address, address);
    function claimable0(address _account) external view returns (uint);
    function claimable1(address _account) external view returns (uint);
    function index0() external view returns (uint);
    function index1() external view returns (uint);
    function balanceOf(address _account) external view returns (uint);
    function approve(address _spender, uint _value) external returns (bool);
    function reserve0() external view returns (uint);
    function reserve1() external view returns (uint);

}
