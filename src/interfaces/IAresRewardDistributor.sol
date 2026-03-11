// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAresRewardDistributor {
    event MerkleRootUpdated(bytes32 newRoot);
    event RewardClaimed(uint256 indexed index, address indexed beneficiaryAddress, uint256 rewardAmountTokens);

    error Ares_AlreadyClaimed();
    error Ares_InvalidProof();
    error Ares_Unauthorized();

    function updateMerkleRoot(bytes32 newRoot) external;
    function isClaimed(uint256 index) external view returns (bool);
    function claim(uint256 index, address beneficiaryAddress, uint256 rewardAmountTokens, bytes32[] calldata merkleProof) external;
}
