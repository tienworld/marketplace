// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";

contract ETHFundNFT is ERC1155 {
    
    using Counters for Counters.Counter;

     // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Base uri
    string private _baseUri;

    Counters.Counter private _tokenIds;

    constructor (string memory base_uri, string memory name_, string memory symbol_) ERC1155(base_uri){
        _name = name_;
        _symbol = symbol_;
        _baseUri = base_uri;
    }

    struct Item {
        uint256 id;
        address creator;
        address receiver;
        uint256 royality;
        string uri;
    }
   
    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 0;
    }

    mapping (uint256 => Item) public Items;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    event itemCreated(uint256 id, address tokenAddress, address creator, uint256 supply, uint256 royality);

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return Items[tokenId].creator != address(0);
    }

    function mint(uint256 royality, address receiver, uint256 supply, string memory token_uri) public returns (uint256){
        require(royality<50000, "ERC1155Metadata: royality can't be more then 50%");
        require(supply>0, "ERC1155Metadata: supply can't be less then 1");
        require(supply<=10000, "ERC1155Metadata: supply can't be more then 10000");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId, supply,"");

        Items[newItemId] = Item(newItemId, msg.sender, receiver, royality, token_uri);

        emit itemCreated(newItemId, address(this), msg.sender, supply, royality);

        return newItemId;
    }

    function royaltyInfo(uint256 _tokenId,uint256 _salePrice ) external view returns ( address receiver,uint256 royaltyAmount) {
        require(_exists(_tokenId), "ERC721Metadata: royality query for nonexistent token");
        require(_salePrice<=0, "ERC721Metadata: asking price should be positive number");

        if(Items[_tokenId].royality<=0) return (Items[_tokenId].creator, 0);

        return (Items[_tokenId].creator, Items[_tokenId].royality * _salePrice / 100000); 
    }

    /**
    * @dev Gets the info of a nft
    * @param tokenId id of the nft item
    */
    function getAuction(uint256 tokenId)
        external
        view
        returns (
            uint256 id,
            address creator,
            address receiver,
            uint256 royality
        )
    {
        return (
            Items[tokenId].id,
            Items[tokenId].creator,
            Items[tokenId].receiver,
            Items[tokenId].royality
        );
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: uri query for nonexistent token");
        return Items[_tokenId].uri;
    }
}