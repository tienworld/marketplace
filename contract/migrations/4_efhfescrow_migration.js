const ETHFEscrow = artifacts.require("ETHFEscrow");

module.exports = function (deployer) {
  deployer.deploy(ETHFEscrow);
};
