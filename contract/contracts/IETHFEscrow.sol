// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Required interface of TokenHolder
 */
interface IETHFEscrow {
    /**
     * @dev moves the token to the escrow account
     */
    function escrowToken(address tokenAddress, address _from, uint256 _tokenId, uint256 _tokens) external;

    /**
     * @dev moves the token from escrow to the specified account
     *
     * Requirements:
     *
     * - `contract address` must be approved.
     */
    function transferToken(address tokenAddress, address _to, uint256 _tokenId, uint256 _tokens) external;

    /**
     * @dev check whether a contract is approved or not
     */
    function isContractApproved(address _contract)
        external
        view
        returns (bool approved);
}
