// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { PriceOracle } from "@sense-finance/v1-fuse/src/external/PriceOracle.sol";
import { CToken } from "@sense-finance/v1-fuse/src/external/CToken.sol";

contract MockOracle is PriceOracle {
    uint256 public _price = 1e18;

    function getUnderlyingPrice(CToken) external view override returns (uint256) {
        return _price;
    }

    function price(address) external view override returns (uint256) {
        return _price;
    }

    function setPrice(uint256 price_) external {
        _price = price_;
    }

    function initialize(
        address[] memory underlyings,
        PriceOracle[] memory _oracles,
        PriceOracle _defaultOracle,
        address _admin,
        bool _canAdminOverwrite
    ) external {
        return;
    }

    function add(address[] calldata underlyings, PriceOracle[] calldata _oracles) external {
        return;
    }

    function setZero(address zero, address pool) external {
        return;
    }

    // Chainlink mocks
    function latestRoundData(address base, address quote)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            1, // roundId
            int256(_price), // answer (price)
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );
    }
}
