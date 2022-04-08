const { expect } = require("chai");
const { map } = require("../helpers/constants");

describe("EthRisk", function () {
    let ethRisk, accounts;
    before(async function () {
        const EthRiskContractFactory = await hre.ethers.getContractFactory("EthRisk");
        ethRisk = await EthRiskContractFactory.deploy(map);
        await ethRisk.deployed();
        accounts = await hre.ethers.getSigners();
    });
    describe("New game", function () {
        it("New game emits NewGame event", async function () {
            await expect(ethRisk.newGame([accounts[0].address, accounts[1].address]))
                .to.emit(ethRisk, "NewGame").withArgs(0, accounts[0].address, accounts[1].address);
        });
        it("Game properly added to games array", async function () {
            expect((await ethRisk.games(0)).whoseTurn).to.equal(accounts[0].address);
        });
        it("Territories state properly initialized", async function () {
            expect((await ethRisk.territories(0, 0)).owner).to.equal(accounts[0].address);
            expect((await ethRisk.territories(0, map.length - 1)).owner).to.equal(accounts[1].address);
        });
    });
    describe("Troop deployment", function () {
        it("Cannot deploy in enemy territory", async function () {
            await expect(ethRisk.deployTroops(0, map.map((t, i) => {
                if (i == map.length - 1) return 1;
                else return 0;
            }))).to.be.revertedWith("Deployed in invalid territory.");
        });
        it("Cannot deploy too few troops", async function () {
            await expect(ethRisk.deployTroops(0, map.map((t) => 0))).to.be.revertedWith("Invalid amount of troops.");
        });
        it("Cannot deploy too many troops", async function () {
            await expect(ethRisk.deployTroops(0, map.map((t, i) => (i === 0) ? map.length / 2 + 1 : 0)))
                .to.be.revertedWith("Invalid amount of troops.");
        });
        it("Cannot deploy during other player's turn", async function () {
            await expect(ethRisk.connect(accounts[1]).deployTroops(0, []))
                .to.be.revertedWith("Not player's turn.");
        });
    });
    describe("Attacking", function () {
        before(async function () {
            await ethRisk.deployTroops(0, map.map((t, i) => (i === 0) ? map.length / 2 : 0));
        });
        it("Game status changed properly", async function () {
            expect((await ethRisk.games(0)).status).to.equal(1);
        });
        it("Cannot attack with zero troops", async function () {
            await expect(ethRisk.conductAttacks(0, map.map((t, i) => {
                if (i === map.length - 1 || i === 0) return 0;
                else return -1;
            }))).to.be.revertedWith("Not enough attacking troops.");
        });
        it("Cannot attack with more troops than available", async function () {
            await expect(ethRisk.conductAttacks(0, map.map((t, i) => {
                if (i === 1) return 2;
                else if (i === map.length -1) return 1;
                else return -1;
            }))).to.be.revertedWith("Too many troops attacking.");
        });
        it("Cannot attack from one territory more than once", async function () {
            await expect(ethRisk.conductAttacks(0, map.map((t, i) => {
                if (i === 0) return 3;
                else if (i === 35 || i === map.length - 1) return 0;
                else return -1;
            }))).to.be.revertedWith("Territory can only attack once.");
        });
        it("Cannot attack non-neighbor territory", async function () {
            await expect(ethRisk.conductAttacks(0, map.map((t, i) => {
                if (i === 0) return 1;
                else if (i === map.length - 1) return 0;
                else return -1;
            }))).to.be.revertedWith("Can only attack neighbor.");
        });
        it("concludeAttack functions properly", async function () {
            await ethRisk.concludeAttack(0);
            expect((await ethRisk.games(0)).status).to.equal(2);
        });
    });
    describe("Fortifying", async function () {
        it("Cannot fortify more troops than available", async function () {
            await expect(ethRisk.fortify(0, 1, 0, 3)).to.be.revertedWith("Can't fortify that many troops.");
        });
        it("Cannot fortify to or from enemy territory", async function () {
            await expect(ethRisk.fortify(0, 0, map.length - 1, 1)).to.be.revertedWith("Can't fortify in enemy land.");
            await expect(ethRisk.fortify(0, map.length - 1, 0, 1)).to.be.revertedWith("Can't fortify in enemy land.");
        });
        it("Fortifying behaves as expected", async function () {
            await ethRisk.fortify(0, 1, 2, 1);
            expect((await ethRisk.territories(0, 1)).troopCount).to.equal(1);
            expect((await ethRisk.territories(0, 2)).troopCount).to.equal(3);
        });
        it("Status and turn are updated after fortifying", async function () {
            const game = await ethRisk.games(0);
            expect(game.status).to.equal(0);
            expect(game.whoseTurn).to.equal(accounts[1].address);
        });
    });
});

