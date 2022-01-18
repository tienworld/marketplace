const ETHFundNFT = artifacts.require("ETHFundNFT");

module.exports = function (deployer) {
  //string memory base_uri, string memory name_, string memory symbol_
  deployer.deploy(ETHFundNFT, process.env.METAURI, process.env.TOKENMAME, process.env.SYMBOL);
};
