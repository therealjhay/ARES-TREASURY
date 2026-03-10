// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAresTreasury} from "../interfaces/IAresTreasury.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AresRewardDistributor
 * @notice Scalable Merkle-based reward claim system.
 * @dev Extremely generic gas efficient double claim protection using a bitmap.
 */
contract AresRewardDistributor is IAresTreasury {
    using SafeERC20 for IERC20;

    bytes32 public merkleRoot;
    IERC20 public immutable rewardToken;
    address public immutable owner;

    // Bitmap tracks claims by user index to save massive gas.
    // 256 bits per slot, saving 255 mappings per full slot vs address => bool.
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

    /**
     * @notice Updates the Merkle root for new claim epochs.
     */
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    /**
     * @notice Checks if an index has been claimed.
     * @dev Extracts the word index and the bit index.
     */
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
     * @notice Sets an index as claimed.
     */
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /**
     * @notice Claims rewards for a given index and amount.
     */
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        if (isClaimed(index)) revert Ares_AlreadyClaimed();

        // Verify the merkle proof.
        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert Ares_InvalidProof();

        // Mark it claimed and send the token.
        _setClaimed(index);
        
        // Use CEI - state is updated before external call
        rewardToken.safeTransfer(account, amount);

        emit RewardClaimed(index, account, amount);
    }
}
