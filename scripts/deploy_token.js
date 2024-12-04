const hre = require("hardhat");
const fs = require('fs');

async function main() {
  const TokenContract = await hre.ethers.getContractFactory("Token");
  const tokenContract = await TokenContract.deploy();
  await tokenContract.waitForDeployment(); //sửa deloyed

  try {
    const tokenAddress = await tokenContract.getAddress(); // dùng getAddress() thay vì address
    fs.writeFileSync('./token_address.txt', tokenAddress); 
    console.log(`Successfully wrote token address ${tokenAddress} to token_address.txt`);
  } catch (error) {
    console.log(`Failed to write to file`);
    console.log(`Manually input token address: ${tokenAddress}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });