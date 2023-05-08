// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './KIP7.sol';

contract AmoCoin is KIP7 { 
    constructor() KIP7("AMO Coin", "AMO", 18, 21_200_000_000 * 1e18) {}
}