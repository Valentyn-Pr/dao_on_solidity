// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {DAOContract} from "../src/DAOContract.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract MockGovToken is ERC20 {
    constructor() ERC20("GovToken", "GT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}


contract CounterTest is Test {
    MockGovToken public govToken;
    DAOContract public dao;
    address public voter = address(0x1);
    address public proposalExecutor = address(0x2);

    event Voted(uint proposalId, address voter, bool vote, uint amount);

    function setUp() public {
        govToken = new MockGovToken();
        dao = new DAOContract(
            address(govToken),
            100,
            10 minutes
        );
        // some tokens for voter
        govToken.mint(voter, 100000);
        // and some to dao owner. only owner can create proposal
        govToken.mint(address(this), 2000000);
        // and of course add some tokens for contract to reward propodal executor
        govToken.mint(address(dao), 10**3);
    }

    function test_create_proposal() public {
        bytes memory proposal_code = abi.encodeWithSelector(bytes4(keccak256("setTheX(uint8)")), uint8(27));
        dao.createProposal(
            "Hi folks, I propose to set theX variable ot 27 - my age eventually. proposalCode is keccak256 for setTheX(uint8) with argument 27",
            proposal_code
        );
        console.logBytes(proposal_code);
        assert(dao.proposalCount() == 1);
    }

    function test_positive_vote() public {
        test_create_proposal();

        vm.startPrank(voter);

        uint256 amount = govToken.balanceOf(voter); // read once

        // tell foundry what data to expect -> check 3 topics and data
        vm.expectEmit(true, true, true, true);

        // Emit expected event to say foundry what event is expected after this line
        emit Voted(1, voter, true, amount);

        dao.vote(1, true);

        assert(dao.getProposal(1).supportedCnt == amount);

        vm.stopPrank();
    }

    function test_proposal_accepted() public {
        test_positive_vote(); // creates vote and votes for that
        // we do not want to wait voting end
        vm.warp(block.timestamp + 11 minutes);

        // This will fail the test if it reverts
        dao.canExecuteProposalCheck(1);
    }

    function test_proposal_executed() public {
        test_proposal_accepted(); // creates vote, votes, modifies time so proposal can be executed
        // check executor does not have tokens
        vm.startPrank(proposalExecutor);
        assert(govToken.balanceOf(proposalExecutor) == 0);

        // store old value of theX variable before proposal execution
        uint8 theXbeforeProposalAccepted = dao.getTheX();

        dao.executeProposal(1);
        // check executor is rewarded. only verify its balance not 0
        assert(govToken.balanceOf(proposalExecutor) == dao.getExecutorReward());
        vm.stopPrank();

        uint8 theXafterProposalAccepted = dao.getTheX();
        assert(theXbeforeProposalAccepted != theXafterProposalAccepted);
        // check proposal is executed
        assert(dao.getProposal(1).isExecuted == true);
    }

    function test_proposal_is_not_votable_after_deadline() public  {
        test_proposal_executed(); // makes current time exceed voting deadline

        vm.expectRevert("voting too late...");
        dao.vote(1, true);
    }
}
