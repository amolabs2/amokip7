import { ethers } from 'hardhat';

async function main() {
  const AmoCoin = await ethers.getContractFactory('AmoCoin');
  const amoCoin = await AmoCoin.deploy();
  await amoCoin.deployed();
  console.log('AmoCoin이 배포된 컨트랙트의 주소 : ', amoCoin.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
