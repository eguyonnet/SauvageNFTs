require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-watcher");
require("hardhat-log-remover");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address + " - " + account.balance);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.5.0",
      },
      {
        version: "0.8.10",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: process.env.DEFAULT_NETWORK || "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      loggingEnabled: true,
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
      blockGasLimit: 1_000_000_000,
    },
    localhost: {
      url: process.env.LOCAL_NODE || "",
    },
    rinkeby: {
      url: process.env.RINKEBY_URL || "",
      accounts:
        process.env.RINKEBY_PRIVATE_KEY !== undefined
          ? [process.env.RINKEBY_PRIVATE_KEY]
          : [],
    },
  },
  // https://hardhat.org/plugins/hardhat-gas-reporter.html
  gasReporter: {
    enabled: process.env.REPORT_GAS,
    currency: "EUR",
    coinmarketcap: process.env.COINMARKETCAP_KEY,
    // gasPrice : 21
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 1800000,
  },
  watcher: {
    compilation: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    },
  },
};
