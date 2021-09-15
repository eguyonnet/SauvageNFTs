const { expect } = require("chai");
//const { ethers } = require("hardhat");

// All tests for the SauvageOne contract
describe("SauvageOne contract", function () {

  const tokenName = "SauvageOne";
  const tokenSymbol = "SVG1";
  const tokenMaxSupply = 10;

  let Token;
  let hardhatToken;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    Token = await ethers.getContractFactory("SauvageOne");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    hardhatToken = await Token.deploy(tokenName, tokenSymbol, tokenMaxSupply);
  });

  describe("Deployment", function () {

    it("Check init values", async function () {
      expect(await hardhatToken.name()).to.equal(tokenName);
      expect(await hardhatToken.symbol()).to.equal(tokenSymbol);
      expect(await hardhatToken.maxSupply()).to.equal(tokenMaxSupply);
      expect(await hardhatToken.totalSupply()).to.equal(0);
      expect(await hardhatToken.owner()).to.equal(owner.address);
    });

    /*
    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await hardhatToken.balanceOf(owner.address);
      expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
    });
    */

  });

  describe("Transactions", function () {

    it("Should fail when a new token is minted above maxSupply", async function () {
      await expect(
        hardhatToken.claim(tokenMaxSupply)
      ).to.be.revertedWith("Invalid token Id");
    });

    it("When a new token is minted within maxSupply, totalSupply should increase by 1", async function () {
      const claimTx = await hardhatToken.claim(0);
      await claimTx.wait();
      expect(await hardhatToken.totalSupply()).to.equal(1);
      // force log
      await hardhatToken.tokenURI(0);
    });

  });
  
});
