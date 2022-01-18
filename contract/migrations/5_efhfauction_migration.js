const ETHFAuction = artifacts.require("ETHFAuction");

module.exports = function (deployer) {
  deployer.deploy(ETHFAuction,process.env.ESCROW, process.env.FEESWALLET, process.env.FEESBASIS||2500);
};
