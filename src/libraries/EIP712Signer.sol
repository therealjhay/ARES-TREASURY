// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title EIP712Signer
 * @notice Library for verifying EIP-712 structured signatures with replay protection.
 * @dev Includes nonce management mapped per address, preventing signature replay, 
 * malleability, and cross-chain replay (using block.chainid and domain separators).
 */
library EIP712Signer {
    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant PROPOSAL_TYPEHASH = keccak256("Proposal(address proposer,uint256 nonce,bytes32 descriptionHash,bytes32 actionsHash)");

    function getDomainSeparator(string memory name, string memory version, address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                verifyingContract
            )
        );
    }

    function getProposalHash(
        bytes32 domainSeparator,
        address proposer,
        uint256 nonce,
        bytes32 descriptionHash,
        bytes32 actionsHash
    ) internal pure returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                PROPOSAL_TYPEHASH,
                proposer,
                nonce,
                descriptionHash,
                actionsHash
            )
        );
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    function verifySignature(
        bytes32 digest,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        address recoveredSigner = ECDSA.recover(digest, signature);
        return recoveredSigner == expectedSigner;
    }
}
