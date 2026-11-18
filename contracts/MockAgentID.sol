// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockAgentID
 * @notice TEST-ONLY stand-in for the real Binance Agent ID ERC-721
 *         (0x60b9262456de011f7d15a54cdd8c48baaa8b022f on BNB Chain).
 *         Implements just enough ERC-721 for AgentStamp's gate:
 *         a permissionless mint() (tests only!) and balanceOf().
 *         NEVER deploy this on a live network.
 */
contract MockAgentID {
    string public constant name = "Mock Agent ID";
    string public constant symbol = "MAID";

    uint256 private _nextId = 1;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice Permissionless on purpose: tests need to give any account an
    ///         "Agent ID" freely. The real Agent ID contract does not work
    ///         like this.
    function mint(address to) external returns (uint256 tokenId) {
        require(to != address(0), "MockAgentID: zero address");
        tokenId = _nextId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "MockAgentID: zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "MockAgentID: nonexistent token");
        return owner;
    }
}
