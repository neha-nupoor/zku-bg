// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/** 
 * @title Ballot
 * @dev Implements voting process along with vote delegation
 */
contract Ballot {
   
    struct Voter {
        uint64 weight; // weight is accumulated by delegation
        uint64 voted;  // if true, that person already voted
        uint128 vote;   // index of the voted proposal
        bytes32 delegate; // person delegated to
    }

    struct Proposal {
        // If you can limit the length to a certain number of bytes, 
        // always use one of bytes1 to bytes32 because they are much cheaper
        uint128 voteCount; // number of accumulated votes
        bytes32 name;   // short name (up to 32 bytes)
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    /** 
     * @dev Create a new ballot to choose one of 'proposalNames'.
     * @param proposalNames names of proposals
     */
    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for (uint i = 0; i < proposalNames.length; i++) {
            // 'Proposal({...})' creates a temporary
            // Proposal object and 'proposals.push(...)'
            // appends it to the end of 'proposals'.
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }
    
    /** 
     * @dev Give 'voterList' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voterList address of voter
     */
     // https://ethereum.stackexchange.com/questions/77069/error-encoding-arguments-error-invalid-bytes32-value-arg-codertype-bytes 
     // using bytes from here to save some more gas
    function giveRightToVote(bytes[] memory voterList) public {

        // batch process all voters' right to vote.
        // changed the struct data types to uint64/64/128 for slotting together in compiler
        // used bytes[] instead of address
        // Possible enhancement: instead of bytes[], use bytes32[]. 
            // Was not able to make the call from Remix with correct data length. Some padding might have fixed it, but could not figure it out.

        // interesting observation : gas increases if I combine the require conditions with an &&

        require(msg.sender == chairperson, "not a chairperson, operation not allowed");
        for (uint i = 0; i<voterList.length; i++) {
            bytes memory voterBytes = voterList[i];
            address voter = bytesToAddressFn(voterBytes);
            require(
                (voters[voter].voted == 0),
                "The voter already voted."
            );
            require(
                (voters[voter].weight == 0),
                "The voter alis not allowed to vote."
            );

            voters[voter].weight = 1;
        }
        
    }

    // https://ethereum.stackexchange.com/questions/884/how-to-convert-an-address-to-bytes-in-solidity
    function addrToBytes32(address a) private pure returns (bytes32 b){
        return bytes32(uint256(uint160(a)) << 96);
    }

    function bytestoAddress(bytes32 b) public pure returns (address a) {
        return address(uint160(uint256(b)));
    }
    // https://ethereum.stackexchange.com/questions/15350/how-to-convert-an-bytes-to-address-in-solidity
    function bytesToAddressFn(bytes memory bys) private pure returns (address  addr) {
        assembly {
            addr := mload(add(bys, 32))
        } 
    }


    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        bytes32 bytesAddr = addrToBytes32(to);
        Voter storage sender = voters[msg.sender];
        require(sender.voted != 0, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[to].delegate != bytesAddr) {
            bytesAddr = voters[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }
        sender.voted = 1;
        sender.delegate = addrToBytes32(to);
        Voter storage delegate_ = voters[to];
        if (delegate_.voted == 1) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposal index of proposal in the proposals array
     */
    function vote(uint128 proposal) public {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(sender.voted != 0, "Already voted.");
        sender.voted = 1;
        sender.vote = proposal;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;
    }

    /** 
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningProposal_ index of winning proposal in the proposals array
     */
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    /** 
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function winnerName() public view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[winningProposal()].name;
    }
}
