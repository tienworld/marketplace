// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IETHFEscrow.sol";
import "./IERC2981.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ETHFAuction {
    AuctionItem[] public itemsForAuction;

    //auction id and its bids
    mapping(uint256 => mapping(uint256 => Bid)) bids;

    // initialize the escrow contract
    IETHFEscrow ETHFEscrow;

    //white label threshol
    uint256 private _whitelabel_threshold;

    // White label token
    address private _whitelabel;

    // Fees basis points
    uint256 private _fees_basis;

    // fees wallet address
    address private _feeswallet;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a; // supporting NFT Royalty Standard ERC2981

    // to hold an auction
    struct AuctionItem {
        uint256 id;
        address tokenAddress;
        uint256 tokenId;
        address payable owner;
        uint256 blockDeadline;
        uint256 startPrice;
        uint256 supply;
        bool active;
        bool finalized;
        uint256 latestBidId;
    }

    // to hold bid details
    struct Bid {
        address from;
        uint256 amount;
    }

    constructor(
        address whitelabel_, 
        uint256 whitelabel_threshold_, 
        address escrow_,
        address feeswallet_,
        uint256 fees_basis_
    ) {
        _feeswallet = feeswallet_;
        _fees_basis = fees_basis_;
        _whitelabel = whitelabel_;
        _whitelabel_threshold = whitelabel_threshold_;
        ETHFEscrow = IETHFEscrow(escrow_);
    }

    modifier OnlyWhenHasBalance(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) {
        IERC1155 tokenContract = IERC1155(tokenAddress);
        require(
            tokenContract.balanceOf(msg.sender, tokenId) >= amount,
            "Not enough balance"
        );
        _;
    }

    modifier IsWhiteListed(address account) {
        uint256 ethfBalance = IERC20(_whitelabel).balanceOf(account);        
        require(ethfBalance >= _whitelabel_threshold, "Not enough white balance");
        _;
    }

    modifier AuctionExists(uint256 id) {
        require(
            id < itemsForAuction.length && itemsForAuction[id].id == id,
            "Could not find auction item"
        );
        _;
    }

    /**
     * @dev Creates an auction with the given informatin
     * @param tokenAddress_ address the token
     * @param tokenId uint256 the token id
     * @param startPrice uint256 starting price of the auction
     * @param blockDeadline uint is the timestamp in which the auction expires
     */
    function createAuction(
        address tokenAddress_,
        uint256 tokenId,
        uint256 supply,
        uint256 startPrice,
        uint256 blockDeadline
    ) external OnlyWhenHasBalance(tokenAddress_, tokenId, supply)  IsWhiteListed(msg.sender) {
        uint256 newItemId = itemsForAuction.length;

        itemsForAuction.push(
            AuctionItem(
                newItemId,
                tokenAddress_,
                tokenId,
                payable(msg.sender),
                blockDeadline,
                startPrice,
                supply,
                true,
                false,
                0
            )
        );

        /*
         * escrow the token
         */
        // send token to escrow account
        ETHFEscrow.escrowToken(tokenAddress_, msg.sender, tokenId, supply);

        emit AuctionCreated(
            newItemId,
            itemsForAuction[newItemId].owner,
            tokenAddress_,
            tokenId,
            startPrice,
            blockDeadline,
            supply
        );
    }

    /**
     * @dev Cancels an ongoing auction by the owner
     * @dev token is transfered back to the auction owner
     * @dev Bidder is refunded with the initial amount
     * @param auctionId id of the auction item
     */
    function cancelAuction(uint256 auctionId)
        external
        AuctionExists(auctionId)
    {
        require(
            itemsForAuction[auctionId].owner == msg.sender,
            "not the owner of auction"
        );
        require(itemsForAuction[auctionId].active, "auction cancelled");
        require(!itemsForAuction[auctionId].finalized, "auction already ended");

        // return escrow token to owner
        ETHFEscrow.transferToken(
            itemsForAuction[auctionId].tokenAddress,
            itemsForAuction[auctionId].owner,
            itemsForAuction[auctionId].tokenId,
            itemsForAuction[auctionId].supply
        );

        // return latest bid to the bidder
        if (itemsForAuction[auctionId].latestBidId != 0) {
            address payable bidder = payable(
                bids[auctionId][itemsForAuction[auctionId].latestBidId].from
            );
            bidder.transfer(
                bids[auctionId][itemsForAuction[auctionId].latestBidId].amount
            );
        }

        // mark the auction as cancelled
        itemsForAuction[auctionId].active = false;
        emit AuctionModified(
            auctionId,
            itemsForAuction[auctionId].finalized,
            itemsForAuction[auctionId].active
        );
    }

    /**
     * @dev Gets the info of an auction
     * @param auctionId id of the auction item
     */
    function getAuction(uint256 auctionId)
        external
        view
        returns (
            address tokenAddress,
            address owner,
            uint256 blockDeadline,
            uint256 startPrice,
            uint256 supply,
            bool active,
            bool finalized
        )
    {
        return (
            itemsForAuction[auctionId].tokenAddress,
            itemsForAuction[auctionId].owner,
            itemsForAuction[auctionId].blockDeadline,
            itemsForAuction[auctionId].startPrice,
            itemsForAuction[auctionId].supply,
            itemsForAuction[auctionId].active,
            itemsForAuction[auctionId].finalized
        );
    }

    /**
     * @dev Gets an array of owned auctions
     * @param auctionId id of the auction item
     * @return amount uint256, address of last bidder
     */
    function getCurrentBid(uint256 auctionId)
        external
        view
        returns (uint256, address)
    {
        return (
            bids[auctionId][itemsForAuction[auctionId].latestBidId].amount,
            bids[auctionId][itemsForAuction[auctionId].latestBidId].from
        );
    }

    /**
     * @dev Gets the bid counts of a given auction
     * @param auctionId id of the auction item
     */
    function getBidsCount(uint256 auctionId) external view returns (uint256) {
        return itemsForAuction[auctionId].latestBidId;
    }

    /**
     * @dev Bidder places a bid
     * @dev Auction should be active and not ended
     * @dev Refund previous bidder if a new bid is valid and placed.
     * @param auctionId id of the auction item
     * @param amount uint256 of bid amount
     */
    function bidOnToken(uint256 auctionId, uint256 amount) external payable IsWhiteListed(msg.sender) {
        require(itemsForAuction[auctionId].active, "auction cancelled");
        require(!itemsForAuction[auctionId].finalized, "auction already ended");
        require(
            block.timestamp < itemsForAuction[auctionId].blockDeadline,
            "auction expired"
        );
        require(
            itemsForAuction[auctionId].owner != msg.sender,
            "owner can't bid on their auctions"
        );
        require(
            amount >
                bids[auctionId][itemsForAuction[auctionId].latestBidId].amount,
            "bid amount must be more than last bid"
        );
        require(
            msg.value >
                bids[auctionId][itemsForAuction[auctionId].latestBidId].amount *
                    itemsForAuction[auctionId].supply,
            "amount sent is not sufficient"
        );
        /* send the previous bid to previous bidder */
        if (itemsForAuction[auctionId].latestBidId != 0) {
            address payable bidder = payable(
                bids[auctionId][itemsForAuction[auctionId].latestBidId].from
            );
            bidder.transfer(
                bids[auctionId][itemsForAuction[auctionId].latestBidId].amount
            );
        }
        // increment the bid counter
        itemsForAuction[auctionId].latestBidId =
            itemsForAuction[auctionId].latestBidId +
            1;
        // set the latest bid
        bids[auctionId][itemsForAuction[auctionId].latestBidId].amount = amount;
        bids[auctionId][itemsForAuction[auctionId].latestBidId].from = msg
            .sender;
        emit BidSuccess(auctionId, msg.sender, amount);
    }

    /**
     * @dev Finalized an ended auction
     * @dev The auction should be ended, and there should be at least one bid
     * @dev On success token is transfered to bidder and auction owner gets the amount
     * @param auctionId id of the auction item
     */
    function finalizeAuction(uint256 auctionId) external {
        require(itemsForAuction[auctionId].active, "auction cancelled");
        require(
            block.timestamp > itemsForAuction[auctionId].blockDeadline,
            "auction deadline hasn't reached"
        );

        AuctionItem memory item = itemsForAuction[auctionId];
        
        // only if bid is present
        if (item.latestBidId != 0) {
            
            uint256 royaltiesPaid = 0;
            address payable beneficiary1;

            uint256 amount = bids[auctionId][
                item.latestBidId
            ].amount * item.supply;

            uint256 fees = ((_fees_basis * amount) / 100000);
            address payable house= payable(_feeswallet);

            if (checkRoyalties(item.tokenAddress)) {
                 // contract supports ERC2981 Royalties
                (address recipient, uint256 royalty1) = getRoyalties(item.tokenId, item.tokenAddress, amount);
                beneficiary1 = payable(recipient);

                royalty1 = royalty1 * amount;

                if(item.owner != beneficiary1){ // if seller is not creators, charge royalities.
                    item.owner.transfer(amount-royalty1-fees);
                    if(royalty1>0){
                        beneficiary1.transfer(royalty1); //make payment to creator for royalities
                        royaltiesPaid = royalty1;
                    }
                }else{ // if creators is seller, no royality payments.
                    item.owner.transfer(amount-fees);
                }
                if(fees>0){ 
                    house.transfer(fees); //make payment to marketplace for fees
                }
            }else{
                // no royalties
                item.owner.transfer(amount-fees);
                
                if(fees>0){
                    house.transfer(fees); //make payment to marketplace for fees
                }
            }

            //send the token to winning bidder
            ETHFEscrow.transferToken(
                itemsForAuction[auctionId].tokenAddress,
                bids[auctionId][itemsForAuction[auctionId].latestBidId].from,
                itemsForAuction[auctionId].tokenId,
                itemsForAuction[auctionId].supply
            );
            itemsForAuction[auctionId].finalized = true;
        } else {
            // mark the auction as cancelled
            itemsForAuction[auctionId].active = false;
        }
        emit AuctionModified(
            auctionId,
            itemsForAuction[auctionId].finalized,
            itemsForAuction[auctionId].active
        );
    }

    function checkRoyalties(address _contract) internal view returns (bool) {
      (bool success) = IERC1155(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
      return success;
    }

    function getRoyalties(uint256 tokenId, address _contract, uint256 _salePrice) internal view returns (address, uint256) {
        return IERC2981(_contract).royaltyInfo(tokenId, _salePrice);
    }

    /**
     * @dev Emitted when `from` places a bid for `tokenId` auction with amount `amount`.
     */
    event BidSuccess(uint256 auctionId, address indexed from, uint256 amount);

    /**
     * @dev Emitted when `_owner` creates an auction for `tokenId` with `_startPrice` till `blockDeadline`.
     */
    event AuctionCreated(
        uint256 indexed auctionId,
        address owner,
        address tokenAddress,
        uint256 tokenId,
        uint256 startPrice,
        uint256 blockDeadline,
        uint256 amount
    );

    /**
     * @dev Emitted when `tokenId` auction by `_owner` is cancelled or finalized.
     */
    event AuctionModified(
        uint256 indexed auctionId,
        bool finalized,
        bool active
    );
}
