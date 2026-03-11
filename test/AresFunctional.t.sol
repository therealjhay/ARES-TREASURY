// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AresTreasuryCore} from "../src/core/AresTreasuryCore.sol";
import {AresTimelock} from "../src/modules/AresTimelock.sol";
import {AresProposer} from "../src/modules/AresProposer.sol";
import {AresRewardDistributor} from "../src/modules/AresRewardDistributor.sol";
import {IAresProposer} from "../src/interfaces/IAresProposer.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockTarget {
    uint256 public counter;
    function inc() external payable {
        counter++;
    }
}

contract AresFunctionalTest is Test {
    AresTreasuryCore public core;
    AresTimelock public timelock;
    AresProposer public proposer;
    AresRewardDistributor public distributor;
    MockToken public token;
    MockTarget public target;

    address public guardian = address(0x1111);
    address public owner = address(0x2222);
    
    uint256 public proposerKey = 0xA11CE;
    address public userProposer = vm.addr(proposerKey);

    bytes32 DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 PROPOSAL_TYPEHASH = keccak256("Proposal(address proposer,uint256 nonce,bytes32 descriptionHash,bytes32 actionsHash)");

    function setUp() public {
        address precomputedTimelock = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        address precomputedProposer = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        core = new AresTreasuryCore(precomputedTimelock, guardian);
        timelock = new AresTimelock(address(core), precomputedProposer);
        proposer = new AresProposer(address(timelock));
        
        token = new MockToken();
        distributor = new AresRewardDistributor(address(token), owner);
        target = new MockTarget();

        // Fund user
        vm.deal(userProposer, 10 ether);
        vm.deal(address(core), 100 ether); // Core has funds
    }

    function _signProposal(uint256 pKey, address pAddr, uint256 nonce, bytes32 descHash, IAresProposer.Action[] memory actions) internal returns (bytes memory) {
        bytes32 actionsHash = keccak256(abi.encode(actions));

        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("ARES Proposal")),
                keccak256(bytes("1")),
                block.chainid,
                address(proposer)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                PROPOSAL_TYPEHASH,
                pAddr,
                nonce,
                descHash,
                actionsHash
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_ProposalLifecycleSuccess() public {
        vm.startPrank(userProposer);

        IAresProposer.Action[] memory actions = new IAresProposer.Action[](1);
        actions[0] = IAresProposer.Action({
            destinationContract: address(target),
            ethAmount: 0.1 ether,
            signature: "",
            payloadData: abi.encodeWithSelector(MockTarget.inc.selector)
        });

        bytes32 descHash = keccak256("Increment target");
        bytes memory sig = _signProposal(proposerKey, userProposer, 0, descHash, actions);

        uint256 pId = proposer.createProposal{value: 0.1 ether}(userProposer, actions, descHash, sig);
        
        vm.stopPrank();

        // Queue
        uint256 delay = 1 days;
        proposer.queueProposal(pId, delay);

        // Advance time
        vm.warp(block.timestamp + delay + 1);

        // Execute
        uint256 startBalance = address(target).balance;
        uint256 startCounter = target.counter();
        proposer.executeProposal(pId);

        assertEq(target.counter(), startCounter + 1);
        assertEq(address(target).balance, startBalance + 0.1 ether);
    }
}
