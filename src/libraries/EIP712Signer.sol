// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


library EIP712Signer {
    // Type hashes define the structure of the data being signed
    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant PROPOSAL_TYPEHASH = keccak256("Proposal(address proposer,uint256 nonce,bytes32 descriptionHash,bytes32 actionsHash)");

    // Creates the domain separator which binds the signature to this specific contract and chain
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

    // Creates the final hash of the proposal data
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
        // Combine domain separator and struct hash based on EIP-712 rules
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    // Checks if the signature was actually signed by the expected address
    function verifySignature(
        bytes32 digest,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        address recoveredSigner = ECDSA.recover(digest, signature);
        return recoveredSigner == expectedSigner;
    }
}
