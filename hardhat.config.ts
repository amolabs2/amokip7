import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();


const config: HardhatUserConfig = {
  solidity: "0.8.10",
  networks: {
    klaytn: {
      url: 'https://api.baobab.klaytn.net:8651',
      accounts: ['YOUR_ACCOUNT'],
    },
    baobab: {
      url:'https://api.baobab.klaytn.net:8651',
      httpHeaders: {
        'Authorization': 'Basic ' + Buffer.from('YOUR_ACCESS_KEY_ID' + ':' + 'YOUR_SECRET_ACCESS_KEY').toString('base64'),
        'x-chain-id': '1001',
      },
      accounts: [
        'YOUR_ACCOUNT'
      ],
      chainId: 1001,
      gas: 8500000,
    },  
    cypress: {
      url: 'https://public-node-api.klaytnapi.com/v1/cypress',
      httpHeaders: {
        'Authorization': 'Basic ' + Buffer.from('YOUR_ACCESS_KEY_ID' + ':' + 'YOUR_SECRET_ACCESS_KEY').toString('base64'),
        'x-chain-id': '8217',
      },
      accounts: [
        'YOUR_ACCOUNT'
      ],
      chainId: 8217,
      gas: 8500000,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: 'YOUR_API_KEY',
  },
};

export default config;