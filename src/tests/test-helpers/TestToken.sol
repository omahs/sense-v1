pragma solidity ^0.8.6;

// Internal references
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(address account, uint256 amount) external virtual {
        _mint(account, amount);
    }
}
