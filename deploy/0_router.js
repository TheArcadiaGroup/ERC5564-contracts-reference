const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  getTxGasCost,
  log
} = require("../js-helpers/deploy");

const _ = require('lodash');

const ammConfig = {
  factory: {
    8081: '0x7E419d10208E21cA60353794f695a71f20d65F89',
  },
  WETH: {
    8081: '0xD9bB7242D8FC9c8E46Ddf4337Caaf76E7216adc0',
  }
}

module.exports = async (hre) => {
    const { ethers, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const deployData = {};

    const chainId = chainIdByName(network.name);

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    log('Splinter Router Contract Deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', deployer);
    log('  - network id:          ', chainId);
    log(' ');

    log('  Deploying Router...');
    const Router = await ethers.getContractFactory('SplinterRouter');
    const RouterInstance = await Router.deploy(ammConfig.factory[chainId], ammConfig.WETH[chainId], deployer)
    const router = await RouterInstance.deployed()
    log('  - Router:         ', router.address);
    deployData['SplinterRouter'] = {
      abi: getContractAbi('SplinterRouter'),
      address: router.address,
      deployTransaction: router.deployTransaction,
    }

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['router']
