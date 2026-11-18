// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AgentStamp
 * @notice Daily check-in dApp exclusively for Binance Agent ID holders.
 *
 *         Agent ID is a non-transferable ERC-721 identity token on BNB Chain
 *         (contract 0x60b9262456de011f7d15a54cdd8c48baaa8b022f). An address
 *         "holds an Agent ID" iff balanceOf(address) > 0 on that contract.
 *         Only holders may call checkIn(), once per UTC day. The contract
 *         tracks each address's total check-ins and current daily streak,
 *         and mints soulbound (non-transferable) ERC-721 badge tokens when
 *         the total check-in count reaches 3, 7, 14, 21 and 30.
 *
 * PERMISSIONS / TRUST DISCLOSURE:
 *         - This contract has NO owner and NO admin functions of any kind.
 *           Nobody can pause it, upgrade it, change the Agent ID address,
 *           mint badges manually, or alter anyone's stats. The Agent ID
 *           contract address is set once in the constructor and is immutable.
 *         - This contract NEVER custodies, receives, or transfers user
 *           assets. It has no payable functions, no receive/fallback, and
 *           contains no ERC-20/ERC-721 transfer calls on user funds. The
 *           only tokens it ever moves are its own badges, which it only
 *           mints (never transfers).
 *         - Badges are soulbound: every transfer and approval function
 *           reverts. A badge can never leave the address that earned it.
 */

/// @notice Minimal read interface for the Binance Agent ID ERC-721 contract.
///         AgentStamp only needs balanceOf() to gate check-ins.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentStamp {
    // ------------------------------------------------------------------
    // ERC-721 metadata (this contract IS the badge collection)
    // ------------------------------------------------------------------
    string public constant name = "AgentStamp Badge";
    string public constant symbol = "STAMP";

    /// @notice The Binance Agent ID contract. Set once, immutable; no admin
    ///         function can ever change it.
    IAgentID public immutable agentId;

    // ------------------------------------------------------------------
    // Check-in state
    // ------------------------------------------------------------------
    struct Stats {
        uint64 totalCheckins;  // lifetime check-in count
        uint64 currentStreak;  // consecutive UTC days, as of lastCheckinDay
        uint64 lastCheckinDay; // UTC day number (block.timestamp / 86400)
        uint8 badgesMask;      // bit i set => milestone i badge earned
    }

    mapping(address => Stats) private _stats;

    /// @notice Total check-ins required for each badge. Index = badge index.
    uint256[5] public milestones = [3, 7, 14, 21, 30];

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event CheckIn(address indexed user, uint256 day, uint256 totalCheckins, uint256 currentStreak);
    event BadgeMinted(address indexed user, uint256 milestone, uint256 tokenId);
    /// @notice Standard ERC-721 Transfer event, emitted only on badge mint
    ///         (from == address(0)). Badges are never transferred afterwards.
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor(address agentIdContract) {
        require(agentIdContract != address(0), "AgentStamp: zero address");
        agentId = IAgentID(agentIdContract);
    }

    // ------------------------------------------------------------------
    // Core flow
    // ------------------------------------------------------------------

    /// @notice Check in for today (UTC). Caller must hold a Binance Agent ID.
    ///         Reverts if the caller holds no Agent ID or already checked in
    ///         today. Mints any milestone badge that becomes due.
    function checkIn() external {
        require(agentId.balanceOf(msg.sender) > 0, "AgentStamp: no Agent ID");
        uint256 today = block.timestamp / 1 days;

        Stats storage s = _stats[msg.sender];
        require(!(s.totalCheckins > 0 && s.lastCheckinDay == today), "AgentStamp: already checked in today");

        // Streak continues only if the last check-in was yesterday.
        if (s.totalCheckins > 0 && s.lastCheckinDay == today - 1) {
            s.currentStreak += 1;
        } else {
            s.currentStreak = 1;
        }
        s.totalCheckins += 1;
        s.lastCheckinDay = uint64(today);

        emit CheckIn(msg.sender, today, s.totalCheckins, s.currentStreak);

        // Mint a badge if this check-in lands exactly on a milestone.
        for (uint256 i = 0; i < milestones.length; i++) {
            if (s.totalCheckins == milestones[i] && (s.badgesMask & uint8(1 << i)) == 0) {
                s.badgesMask |= uint8(1 << i);
                uint256 tokenId = badgeTokenId(msg.sender, i);
                emit Transfer(address(0), msg.sender, tokenId);
                emit BadgeMinted(msg.sender, milestones[i], tokenId);
            }
        }
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice Stats for an address. currentStreak is the *effective*
    ///         streak: it reads 0 once a full day has been missed.
    function getStats(address user)
        external
        view
        returns (uint256 totalCheckins, uint256 currentStreak, uint256 lastCheckinDay, uint8 badgesMask)
    {
        Stats storage s = _stats[user];
        uint256 today = block.timestamp / 1 days;
        uint256 streak = s.currentStreak;
        if (s.totalCheckins == 0 || (s.lastCheckinDay != today && s.lastCheckinDay != today - 1)) {
            streak = 0;
        }
        return (s.totalCheckins, streak, s.lastCheckinDay, s.badgesMask);
    }

    /// @notice Whether `user` has earned the badge for milestone index `i`
    ///         (0..4, corresponding to totals 3, 7, 14, 21, 30).
    function hasBadge(address user, uint256 milestoneIndex) external view returns (bool) {
        require(milestoneIndex < milestones.length, "AgentStamp: bad milestone index");
        return (_stats[user].badgesMask & uint8(1 << milestoneIndex)) != 0;
    }

    /// @notice Deterministic badge token id for a user + milestone index:
    ///         the user's address in the high bytes, milestone index + 1 in
    ///         the lowest byte (so token id 0 is never a valid badge).
    function badgeTokenId(address user, uint256 milestoneIndex) public pure returns (uint256) {
        return (uint256(uint160(user)) << 8) | (milestoneIndex + 1);
    }

    // ------------------------------------------------------------------
    // ERC-721 (badges only — soulbound)
    // ------------------------------------------------------------------

    /// @notice Number of badges owned by `owner` (0..5).
    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "AgentStamp: zero address");
        uint8 mask = _stats[owner].badgesMask;
        uint256 count;
        for (uint256 i = 0; i < 5; i++) {
            if ((mask & uint8(1 << i)) != 0) count++;
        }
        return count;
    }

    /// @notice Owner of a badge token id. The owner is encoded in the id
    ///         itself; reverts if that badge was never minted.
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = address(uint160(tokenId >> 8));
        uint256 idx = tokenId & 0xff;
        require(idx >= 1 && idx <= 5, "AgentStamp: nonexistent token");
        require((_stats[owner].badgesMask & uint8(1 << (idx - 1))) != 0, "AgentStamp: nonexistent token");
        return owner;
    }

    /// @notice On-chain JSON metadata naming the milestone, returned as a
    ///         data:application/json;base64 URI. No external hosting needed.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId); // reverts for nonexistent tokens
        uint256 milestone = milestones[(tokenId & 0xff) - 1];
        string memory m = _toString(milestone);
        string memory json = string(
            abi.encodePacked(
                '{"name":"AgentStamp Badge - ',
                m,
                ' Check-ins",',
                '"description":"Soulbound badge minted by AgentStamp to a Binance Agent ID holder who reached ',
                m,
                ' total daily check-ins. Badges are non-transferable and have no promised value.",',
                '"attributes":[{"trait_type":"Milestone (total check-ins)","value":',
                m,
                '},{"trait_type":"Soulbound","value":"Yes"}]}'
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", _base64Encode(bytes(json))));
    }

    // --- Soulbound: all transfers and approvals revert, always. ---------

    function transferFrom(address, address, uint256) external pure {
        revert("AgentStamp: soulbound, non-transferable");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("AgentStamp: soulbound, non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert("AgentStamp: soulbound, non-transferable");
    }

    function approve(address, uint256) external pure {
        revert("AgentStamp: soulbound, non-transferable");
    }

    function setApprovalForAll(address, bool) external pure {
        revert("AgentStamp: soulbound, non-transferable");
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165
            interfaceId == 0x80ac58cd || // ERC-721
            interfaceId == 0x5b5e139f; // ERC-721 metadata
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// @dev Plain Base64 encoder (standard alphabet, with padding).
    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLength = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLength);
        uint256 j;
        for (uint256 i = 0; i < data.length; i += 3) {
            uint256 a = uint8(data[i]);
            uint256 b = i + 1 < data.length ? uint8(data[i + 1]) : 0;
            uint256 c = i + 2 < data.length ? uint8(data[i + 2]) : 0;
            result[j++] = table[a >> 2];
            result[j++] = table[((a & 3) << 4) | (b >> 4)];
            result[j++] = table[((b & 15) << 2) | (c >> 6)];
            result[j++] = table[c & 63];
        }
        if (data.length % 3 == 1) {
            result[encodedLength - 1] = "=";
            result[encodedLength - 2] = "=";
        } else if (data.length % 3 == 2) {
            result[encodedLength - 1] = "=";
        }
        return string(result);
    }
}
