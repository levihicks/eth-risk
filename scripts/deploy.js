// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { map } = require("../helpers/constants.js");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const EthRiskContractFactory = await hre.ethers.getContractFactory("EthRisk");
  const ethRisk = await EthRiskContractFactory.deploy(map);

  await ethRisk.deployed();

  const newGameTx = await ethRisk.newGame([
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  ]);

  const txData = await newGameTx.wait();

  console.log('gas used: ' + txData.gasUsed);

  console.log("EthRisk deployed to:", ethRisk.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
