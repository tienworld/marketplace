const ETHFMarket = artifacts.require("ETHFMarket");

module.exports = function (deployer) {
  //(address whitelabel_, uint256 whitelabel_threshold_, address feeswallet_, uint256 fees_basis_,)
  deployer.deploy(ETHFMarket,process.env.WHITETOKEN, process.env.WHITETHRESHOLD||1000, process.env.FEESWALLET, process.env.FEESBASIS||2500);
};
