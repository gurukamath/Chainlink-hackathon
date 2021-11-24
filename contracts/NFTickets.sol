// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/ERC1155.sol";
import "smartcontractkit/chainlink-brownie-contracts@0.2.2/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

contract NFTickets is ERC1155, KeeperCompatibleInterface {
    uint256 private _currentEventId = 0;

    // Keeper variables
    uint256 public immutable interval;
    uint256 public lastTimeStamp;
    uint256 public keeperVerificationCounter = 0;
    uint256 public updatesCounter = 0;
    uint256[] private _updatedTickets;



    struct CustomTicket {
        address owner;
        uint256 tokenSalePrice;
        uint256 maxSupply;
        uint percentageOnResale;
        uint256 expirationDateTimestamp;
        string metadataURI; // IPFS URI that contains event name, description, Ticket type, image url.
        bool expired;
    }

    mapping(address => uint256) private revenue;

    mapping(address => CustomTicket[]) public ownedTickets;



    mapping(uint256 => CustomTicket) public nfTickets;

    constructor(uint256 updateInterval)
        ERC1155("https://localhost/NFTickets/{id}.json")
    {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
    }

    event TicketCreation(uint256 _tokenId, uint256 _unitPrice);

    // Event for tickets updated
    event TicketsUpdated(uint256[] _tokenIds);


       // Getter
    function getOwnedTickets(address _account) public view returns(CustomTicket[] memory){
        return ownedTickets[_account];
    }



    //TODO change this
//    function batchCreateEventTickets(CustomTicket[] memory customTickets)
//        public
//    {
//        for (uint256 i; i < customTickets.length; i++) {
//            CustomTicket memory _ticket = customTickets[i];
//            createEventTickets(
//                _ticket.tokenSalePrice,
//                _ticket.maxSupply,
//                _ticket.metadataURI
//            );
//        }
//    }

    /// @dev Function mints a token for a new event
    /// @param _tokenSalePrice denotes the price of a single ticket
    /// @param _maxSupply denotes the total number of tickets available
    /// @param _metadataURI off-chain URI (e.g IPFS) that contains event name, description, Ticket type, image url.
    function createEventTickets(
        uint256 _tokenSalePrice,
        uint256 _maxSupply,
        uint _percentageOnResale,
        uint256 _expirationDateTimestamp,
        string memory _metadataURI
    ) public {
        CustomTicket memory _newTicket;

        _newTicket.owner = msg.sender;
        _newTicket.tokenSalePrice = _tokenSalePrice;
        _newTicket.maxSupply = _maxSupply;
        _newTicket.metadataURI = _metadataURI;
        _newTicket.expired = false;
        _newTicket.percentageOnResale = _percentageOnResale;
        _newTicket.expirationDateTimestamp = _expirationDateTimestamp;
        nfTickets[_currentEventId] = _newTicket;

        //Here we can try to use VRF and _mint a few "special tokens"??
        _mint(msg.sender, _currentEventId, _maxSupply, "");

        ownedTickets[msg.sender].push(_newTicket);

        emit TicketCreation(_currentEventId, _tokenSalePrice);
        _currentEventId += 1;
    }

    /// @dev Allows anyone to buy the token from the event owner
    /// @param _tokenId Token ID that the sender wishes to buy
    /// @param _numberOfTickets Number of Tickets that the owner wishes to buy
    function buyFromOwner(uint256 _tokenId, uint256 _numberOfTickets)
        public
        payable
    {
        address _owner = nfTickets[_tokenId].owner;
        uint256 _balanceOfOwner = balanceOf(_owner, _tokenId);
        require(
            _balanceOfOwner >= _numberOfTickets,
            "The owner does not have enough tickets to sell"
        );

        uint256 _unitPrice = nfTickets[_tokenId].tokenSalePrice;
        uint256 _totalRequestedTicketValue = _unitPrice * _numberOfTickets;
        require(
            msg.value >= _totalRequestedTicketValue,
            "Not enough funds sent to buy the tickets"
        );

        // Don't we need to transfer the eth to the owner's account?
        revenue[_owner] += msg.value;
        _safeTransferFrom(_owner, msg.sender, _tokenId, _numberOfTickets, "");
    }

    /// @dev Allows event owners to withdraw all their earnings
    /// @param _amount Amount that the event owner wishes to withdraw
    function withdrawProceeds(uint256 _amount) public {
        //TODO: Allow owner to withdraw after verifying the following conditions
        /// @dev revenue is non-zero
        /// @dev sender wishes to withdraw less than his total revenue
        /// @dev gaurd against re-entrancy
    }

    // -------- Integrate token URI (No longer required)

//    function setTokenUri(uint256 tokenId, string memory _tokenURI) public {
//        require(
//            msg.sender == nfTickets[tokenId].owner,
//            "Transfer caller is not owner nor approved"
//        );
//        nfTickets[tokenId].metadataURI = _tokenURI;
//    }


    // -------- Keepers integration ------ Work in progress ... (TODO: Migrate ticket processing functions to own library)

    function _updateTickets()
        private
    {
        //TODO solve this issue to store which tickets are being updated
        for (uint256 i =0; i < _currentEventId; i++) {
            if (nfTickets[i].expirationDateTimestamp < block.timestamp && nfTickets[i].expired!=false) {
                nfTickets[i].expired = true;
                _updatedTickets.push(i);
                updatesCounter = updatesCounter + 1;
            }
        }
        // Emit event with updated Tickets
        emit TicketsUpdated(_updatedTickets);
        _updatedTickets = new uint256[](0);
    }


    function checkUpkeep(
        bytes calldata /* checkData */
    ) external override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata performData) external override {
        keeperVerificationCounter = keeperVerificationCounter + 1;
        _updateTickets();
    }
}
