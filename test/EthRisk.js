const { expect } = require("chai");
const { map } = require("../helpers/constants");

describe("EthRisk", function () {
    let ethRisk, accounts;
    before(async function () {
        const EthRiskContractFactory = await hre.ethers.getContractFactory("EthRisk");
        ethRisk = await EthRiskContractFactory.deploy(map);
        await ethRisk.deployed();
        accounts = await hre.ethers.getSigners();
        await ethRisk.newGame([accounts[0].address, accounts[1].address]);
    });
    it("New game is properly set up", async function () {
        expect((await ethRisk.games(0)).whoseTurn).to.equal(accounts[0].address);
        expect((await ethRisk.territories(0, 0)).owner).to.equal(accounts[0].address);
        expect(await ethRisk.playersToGames(accounts[0].address, 0)).to.equal(0);
    });
});

