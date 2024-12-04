const hre = require("hardhat");
const fs = require('fs');

async function main() {
  const ExchangeContract = await hre.ethers.getContractFactory("TokenExchange");
  const exchangeContract = await ExchangeContract.deploy();
  await exchangeContract.waitForDeployment();

  try {
    const exchangeAddress = await exchangeContract.getAddress(); // Lấy địa chỉ hợp đồng
    fs.writeFileSync('./exchange_address.txt', exchangeAddress); // Ghi địa chỉ vào file
    console.log(`Successfully wrote exchange address ${exchangeAddress} to exchange_address.txt`);
  } catch (error) {
    console.log(`Failed to write to file`);
    console.log(`Manually input exchange address: ${exchangeContract.getAddress()}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });