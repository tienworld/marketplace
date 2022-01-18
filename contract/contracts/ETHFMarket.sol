// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "./IERC2981.sol";

contract ETHFMarket {

    constructor (address whitelabel_, uint256 whitelabel_threshold_, address feeswallet_, uint256 fees_basis_) {
        _whitelabel = whitelabel_;
        _feeswallet = feeswallet_;
        _whitelabel_threshold = whitelabel_threshold_;
        _fees_basis = fees_basis_;
    }

    struct AuctionItem {
        uint256 id;
        address tokenAddress;
        uint256 tokenId;
        address payable seller;
        uint256 askingPrice;
        uint256 amount;
    }

    AuctionItem[] public itemsForSale;

    uint256 private _fees_basis;
    uint256 private _whitelabel_threshold;

    // White label token
    address private _whitelabel;
    address private _feeswallet;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a; // supporting NFT Royalty Standard ERC2981

    mapping (address => mapping (address => mapping (uint256 => uint256))) _listings;

    event itemAdded(uint256 id, uint256 tokenId, address tokenAddress, uint256 amount, uint256 askingPrice);
    event itemRemoved(uint256 id, uint256 tokenId, address tokenAddress);
    event itemSold(uint256 id, address buyer, uint256 amount, uint256 askingPrice);
    event logger(string message);

    modifier OnlyWhenHasBalance(address tokenAddress, uint256 tokenId, uint256 amount){
        IERC1155 tokenContract = IERC1155(tokenAddress);
        require(tokenContract.balanceOf(msg.sender, tokenId) >= amount,"Not enough balance");
        _;
    }

    modifier OnlyUnlisted(address tokenAddress, uint256 tokenId, uint256 amount){
        IERC1155 tokenContract = IERC1155(tokenAddress);
        require(tokenContract.balanceOf(msg.sender, tokenId) >= amount,"Not enough balance");
        require( _listings[msg.sender][tokenAddress][tokenId] + amount <= tokenContract.balanceOf(msg.sender, tokenId), "Can't list more than balance");
        _;
    }

    modifier HasTransferApproval(address tokenAddress){
        IERC1155 tokenContract = IERC1155(tokenAddress);
        require(tokenContract.isApprovedForAll(msg.sender, address(this)),"Missing Approvals");
        _;
    }

    modifier ItemExists(uint256 id){
        require(id < itemsForSale.length && itemsForSale[id].id == id, "Could not find item");
        _;
    }

    function listedOn(address tokenAddress, address owner, uint256 tokenId) public view returns(uint256) {
        require(tokenAddress != address(0), "ERC1155: balance query for the zero address");
        require(owner != address(0), "ERC1155: balance owner for the zero address");
        return _listings[owner][tokenAddress][tokenId];
    }

    function addItemToMarket(uint256 tokenId, address tokenAddress, uint256 amount, uint256 askingPrice)
        HasTransferApproval(tokenAddress)
        OnlyUnlisted(tokenAddress, tokenId, amount)
        IsWhiteListed(msg.sender)
        external returns (uint256)
    {
        uint256 newItemId = itemsForSale.length;

        itemsForSale.push(AuctionItem(newItemId, tokenAddress, tokenId, payable(msg.sender), askingPrice, amount));

        _listings[msg.sender][tokenAddress][tokenId] += amount;

        assert(itemsForSale[newItemId].id == newItemId);
        emit itemAdded(newItemId, tokenId, tokenAddress, amount, askingPrice);

        return newItemId;
    }

    function removeItemFromMarket(uint256 id, uint256 tokenId, address tokenAddress) ItemExists(id) external returns(uint256) {
        require(msg.sender == itemsForSale[id].seller, "not seller of listing");

        _listings[msg.sender][tokenAddress][tokenId] -= itemsForSale[id].amount;
        itemsForSale[id].amount = 0;

        emit itemRemoved(id, tokenId, tokenAddress);

        return id;
    }    

    modifier IsForSale(uint256 id, uint256 amount){
        require(amount <= itemsForSale[id].amount, "Not enough items available");
        _;
    }

    modifier IsWhiteListed(address account) {
        uint256 ethfBalance = IERC20(_whitelabel).balanceOf(account);        
        require(ethfBalance >= _whitelabel_threshold, "Not enough white balance");
        _;
    }

    function buyItem(uint256 id, uint256 amount) payable external ItemExists(id) IsForSale(id, amount) IsWhiteListed(msg.sender) {

        require(msg.value >= itemsForSale[id].askingPrice*amount, "Not enough funds sent");
        require(msg.sender != itemsForSale[id].seller, "Can't buy your own item");

        AuctionItem memory item = itemsForSale[id];
        
        itemsForSale[id].amount -= amount;
        _listings[itemsForSale[id].seller][item.tokenAddress][item.tokenId] -= amount;

        uint256 royaltiesPaid = 0;
        address payable beneficiary1;

        IERC1155(item.tokenAddress).safeTransferFrom(item.seller, msg.sender, item.tokenId, amount, "");

        uint256 fees = (_fees_basis * item.askingPrice / 100000) * amount;
        address payable market= payable(_feeswallet);

        if (checkRoyalties(item.tokenAddress)) {
            // contract supports ERC2981 Royalties
            (address recipient, uint256 royalty1) = getRoyalties(item.tokenId, item.tokenAddress, msg.value);
            beneficiary1 = payable(recipient);

            royalty1 = royalty1 * amount;

            if(item.seller != beneficiary1){ // if seller is not creators, charge royalities.
                item.seller.transfer(msg.value-royalty1-fees);
                if(royalty1>0){
                    beneficiary1.transfer(royalty1); //make payment to creator for royalities
                    royaltiesPaid = royalty1;
                }
            }else{ // if creators is seller, no royality payments.
                item.seller.transfer(msg.value-fees);
            }
            if(fees>0){ 
                market.transfer(fees); //make payment to marketplace for fees
            }
        } else {
            // no royalties
            item.seller.transfer(msg.value-fees);
            
            if(fees>0){
                market.transfer(fees); //make payment to marketplace for fees
            }
        }

        emit itemSold(id, msg.sender, amount, item.askingPrice);
    }

    function checkRoyalties(address _contract) internal view returns (bool) {
      (bool success) = IERC1155(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
      return success;
    }

    function getRoyalties(uint256 tokenId, address _contract, uint256 _salePrice) internal view returns (address, uint256) {
        return IERC2981(_contract).royaltyInfo(tokenId, _salePrice);
    }
}
