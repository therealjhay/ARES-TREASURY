// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasury} from "../interfaces/IAresTreasury.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// This contract lets users claim token rewards securely.
// It uses a Merkle Tree so we don't have to store everyone's balance on-chain.
contract AresRewardDistributor is IAresTreasury {
    using SafeERC20 for IERC20;

    // The single hash representing all users and balances
    bytes32 public merkleRoot;
    
    // The token being given away
    IERC20 public immutable rewardToken;
    address public immutable owner;

    // A gas-efficient way to remember who has already claimed.
    // We pack 256 boolean (true/false) values into a single uint256 number.
    mapping(uint256 => uint256) private claimedBitMap;

    event MerkleRootUpdated(bytes32 newRoot);
    event RewardClaimed(uint256 indexed index, address indexed account, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Ares_Unauthorized();
        _;
    }

    constructor(address _rewardToken, address _owner) {
        if (_rewardToken == address(0) || _owner == address(0)) revert Ares_Unauthorized();
        rewardToken = IERC20(_rewardToken);
        owner = _owner;
    }

    // The owner can update the root to add new rewards
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    // Check if a specific user index has already claimed their reward
    function isClaimed(uint256 index) public view returns (bool) {
        // Find which 256-bit block the user belongs to
        uint256 claimedWordIndex = index / 256;
        // Find their specific spot inside that block
        uint256 claimedBitIndex = index % 256;
        
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        
        // Create a mask (e.g., 00001000) to check just their spot
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    // Mark a user's spot as claimed
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        
        // Flip their specific bit to 1 (true)
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    // Users call this to get their tokens
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        // Prevent claiming twice!
        if (isClaimed(index)) revert Ares_AlreadyClaimed();

        // Check if their proof matches the merkle root we stored
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert Ares_InvalidProof();

        // Record their claim in history BEFORE sending tokens
        _setClaimed(index);
        
        // Send the tokens safely
        rewardToken.safeTransfer(account, amount);

        emit RewardClaimed(index, account, amount);
    }
}
