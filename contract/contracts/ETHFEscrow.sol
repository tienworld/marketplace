// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IETHFEscrow.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract ETHFEscrow is ERC1155Holder, Ownable, IETHFEscrow {

    // map address with approval status
    mapping(address => bool) private approvedContracts;

    /**
     * @dev External function to transfer the token
     * @dev moves the token from holder contract
     * @param tokenAddress address the token
     * @param _to address represents the receiver
     * @param _tokenId uint256 represents the token id
     */
    function transferToken(address tokenAddress, address _to, uint256 _tokenId, uint256 _tokens) external override {
        // check sender approved
        require(approvedContracts[msg.sender], "Contract is not approved");
        // transfer the nft
        IERC1155(tokenAddress).safeTransferFrom(address(this), _to, _tokenId, _tokens, "");
    }

    /**
     * @dev External function to set contract approval
     * @dev sets the access to the given contract to move tokens
     * @param _contract address represents the contracts address
     * @param _approval bool represents the approval for the contract
     */
    function setContractApproval(address _contract, bool _approval)
        external
        onlyOwner
    {
        approvedContracts[_contract] = _approval;
        emit ContractApproval(_contract, _approval);
    }

    /**
     * @dev External function to get contract approval status
     * @param _contract address represents the contracts address
     */
    function isContractApproved(address _contract)
        external
        view
        override
        returns (bool approved)
    {
        return approvedContracts[_contract];
    }

    /**
     * @dev External function to escrow the token into this contract
     * @param tokenAddress address the token
     * @param _from address represents the contracts address
     * @param _tokenId uint256 represents the token id
     */
    function escrowToken(address tokenAddress, address _from, uint256 _tokenId, uint256 _tokens) external override {
        require(approvedContracts[msg.sender], "Contract is not approved");
        IERC1155(tokenAddress).safeTransferFrom(_from, address(this), _tokenId, _tokens, "");
    }

    /**
     * @dev Emitted when `contractAddress` receives `approval`
     */
    event ContractApproval(address indexed contractAddress, bool approval);

}
