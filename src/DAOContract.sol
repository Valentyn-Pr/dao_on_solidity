// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DAOContract is Ownable{
    event ProposalCreated(uint proposalId, address creator, string description);
    event ProposalExecuted(uint proposalId, address executor, bool rewarded);
    event Voted(uint proposalId, address voter, bool vote, uint amount);

    // Flag to allow execution of internal functions
    bool private _executingProposal = false;
    uint8 private theX = 1;
    uint private executorReward = 1000;

    // getters for everyone to see the state
    function getTheX() public view returns(uint8){
        return theX;
    }
    function getExecutorReward() public view returns(uint){
        return executorReward;
    }

    // internal functions that can be used for proposal callData
    function setTheX(uint8 _x) public {
        require(_executingProposal, "only contract can execute setTheX via proposal execution");
        theX = _x;
    }
    function setExecutorReward(uint _newExecutorReward) public {
        require(_executingProposal, "only contract can execute setTheX via proposal execution");
        executorReward = _newExecutorReward;
    }

    struct Proposal {
        uint id;
        string description;
        bytes codeToExecute;
        bool isExecuted;
        uint supportedCnt;
        uint rejectedCnt;
        uint votingDeadline;
    }

    modifier validProposalId(uint256 _proposalId) {
        _validProposalId(_proposalId);
        _;
    }

    function _validProposalId(uint256 _proposalId) internal view {
        require(
            _proposalId <= proposalCount,
            "DAO says: Invalid proposal ID. This is not how you get reward :)"
        );
    }

    uint8 public constant QUORUM_PERCENTAGE = 51;

    // proposals storage
    // key ID(proposal number) | value - proposal data
    mapping(uint => Proposal) public proposals;
    // proposal ID => (voter address => voted or not)
    mapping(uint => mapping(address => bool)) hasVoted;

    function getProposal(uint256 _proposalId) public view validProposalId(_proposalId) returns(Proposal memory){
        return proposals[_proposalId];
    }

    uint public proposalCount;
    uint public minTokensToCreateProposal;
    uint public votingPeriod = 10 minutes;  // for fast and furious !!!

    IERC20 public immutable GOVERNANCE_TOKEN;

    constructor(
        address _governanceToken,
        uint _minTokensToCreateProposal,
        uint _votingPeriod
    ) Ownable(msg.sender) {
        require(_governanceToken != address(0), "gov token addr can not be 0!");

        GOVERNANCE_TOKEN = IERC20(_governanceToken);
        minTokensToCreateProposal = _minTokensToCreateProposal;
        votingPeriod = _votingPeriod;
    }

    function createProposal(
        string memory _description,
        bytes calldata _proposalCode
    ) public onlyOwner {
        require(bytes(_description).length > 10, "description should contain something");
        require(_proposalCode.length > 0, "no calldata for proposal. what you want to do???");
        require(
            GOVERNANCE_TOKEN.balanceOf(msg.sender) >= minTokensToCreateProposal,
            "insufficient governance tokens to create proposal"
        );

        proposalCount++;
        uint currentId = proposalCount;

        uint deadline = block.timestamp + votingPeriod;

        proposals[currentId] = Proposal({
            id: currentId,
            description: _description,
            codeToExecute: _proposalCode,
            isExecuted: false,
            supportedCnt: 0,
            rejectedCnt: 0,
            votingDeadline: deadline
        });

        emit ProposalCreated(currentId, msg.sender, _description);
    }

    function vote(uint _proposalId, bool _vote) external validProposalId(_proposalId){
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.votingDeadline, "voting too late...");

        // works because default value for bool is false.
        require(!hasVoted[_proposalId][msg.sender], "already voted");

        uint voterBalance = GOVERNANCE_TOKEN.balanceOf(msg.sender);
        // everyone with non-zero balance can vote
        require(voterBalance > 0, "insufficient tokens to vote...");

        if (_vote){
            p.supportedCnt += voterBalance;
        } else {
            p.rejectedCnt += voterBalance;
        }

        emit Voted(_proposalId, msg.sender, _vote, voterBalance);
    }

    // for easier UI usage
    // in UI - if transaction status is 'true' - check passed
    // but can be rewritten to other logic
    function canExecuteProposalCheck(uint256 _proposalId) public view validProposalId(_proposalId){
        Proposal storage p = proposals[_proposalId];
        require(
            !p.isExecuted,
            "DAO says: proposal already executed. You just wasted your gas :)"
        );
        require(
            block.timestamp >= p.votingDeadline,
            "DAO says: you are executing to early. try later :0"
        );

        uint totalVotes = p.supportedCnt + p.rejectedCnt;
        uint quorum = totalVotes * QUORUM_PERCENTAGE / 100;
        require(
            p.supportedCnt > quorum,
            "DAO says: quorum haven't been reached for this proposal."
        );
        // check if balance is enought for rewarding
        uint256 contractTokensBalance = GOVERNANCE_TOKEN.balanceOf(address(this));
        require(
            contractTokensBalance >= executorReward,
            "DAO says: try again later. Contract does not have enough tokens to reward you"
        );
    }


    function executeProposal(uint256 _proposalId) external{
        // will revert in case checks not passed
        canExecuteProposalCheck(_proposalId);

        Proposal storage p = proposals[_proposalId];
        _executingProposal = true; // allows protected functions calls
        (bool success, ) = address(this).call(p.codeToExecute);
        _executingProposal = false; // blocks protected functions calls
        require(success, "proposal callData execution failed");

        bool executorRewarded =  GOVERNANCE_TOKEN.transfer(msg.sender, executorReward);


        p.isExecuted = true;
        emit ProposalExecuted(_proposalId, msg.sender, executorRewarded);
    }


}
