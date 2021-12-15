const { BigNumber } = require("@ethersproject/bignumber");
const { checkProperties } = require("@ethersproject/properties");
const { expect } = require("chai");
const { ethers } = require("hardhat");

// All tests for the SauvageOne contract
describe("SauvageOne contract", function () {
  const tokenName = "SauvageOne";
  const tokenSymbol = "SVG1";
  const tokenPrice = "50000000000000000"; // 0,5 ETH
  const tokenMaxSupply = 10;
  const maxTokensClaimable = 3;
  
  let Contract;
  let instance;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addrs;

  beforeEach(async function () {
    Contract = await ethers.getContractFactory("SauvageOne");
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    instance = await Contract.deploy(tokenName, tokenSymbol, tokenPrice, tokenMaxSupply);
  });

  describe("Deployment", function () {

    it("Check init values", async function () {
      // Check contructor input parameters
      expect(await instance.name()).to.equal(tokenName);
      expect(await instance.symbol()).to.equal(tokenSymbol);
      expect(await instance.pricePerToken()).to.equal(tokenPrice);
      expect(await instance.maxSupply()).to.equal(tokenMaxSupply);
      // No token minted yet
      expect(await instance.totalSupply()).to.equal(0);
      // Owner is the address that deployed the contract
      expect(await instance.owner()).to.equal(owner.address);
      // Default status is INIT
      expect(await instance.currentPeriod()).to.equal(0);
      // Contract balance = 0
      expect(await instance.balanceOf(instance.address)).to.equal(0);
    });

    /*
    it("Should assign the total supply of tokens to the owner", async
     function () {
      const ownerBalance = await instance.balanceOf(owner.address);
      expect(await instance.totalSupply()).to.equal(ownerBalance);
    });
    */

  });


  describe("Start presale period", function () {
  
      it("Only owner can start presale period", async function () {
        await expect(
          instance.connect(addr1).startPresale()
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("Proper initialization of presale period", async function () {
        await instance.startPresale();
        expect(await instance.currentPeriod()).to.equal(1);
        expect(await instance.getWhitelistSize()).to.equal(0);
      });
  });

  describe("Whitelist management", function () {
      
      it("Current period must be PRESALE to add addresses in whitelist", async function () {
        const addToWL = [owner.address, addr1.address, addr1.address, addr2.address];
        await expect(
          instance.addToWhitelist(addToWL)
        ).to.be.revertedWith("Invalid period");
      });

      it("Only owner can add addresses to whitelist", async function () {
        const addToWL = [owner.address, addr1.address, addr1.address, addr2.address];
        await instance.startPresale();
        await expect(
          instance.connect(addr1).addToWhitelist(addToWL)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("Only add necessary addresses to whitelist", async function () {
        const addToWL = [owner.address, addr1.address, addr1.address, addr2.address];
        await instance.startPresale();
        expect(await instance.currentPeriod()).to.equal(1);
        await instance.addToWhitelist(addToWL);
        expect(await instance.getWhitelistSize()).to.equal(2);
        expect(await instance.isWhiteListed(owner.address)).to.equal(false);
        expect(await instance.isWhiteListed(addr1.address)).to.equal(true);
        expect(await instance.isWhiteListed(addr3.address)).to.equal(false);
        expect(await instance.connect(addr1).amIWhiteListed()).to.equal(true);
        expect(await instance.connect(addr3).amIWhiteListed()).to.equal(false);
      });
        
      it("Only owner can request whitelist size", async function () {
        await expect(
          instance.connect(addr1).getWhitelistSize()
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
        
      it("Only owner can request if a specific addresse is in whitelist", async function () {
        await expect(
          instance.connect(addr1).isWhiteListed(addr3.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
      
  });

  describe("Start sale period", function () {
  
      it("Only owner can start sale period", async function () {
        await expect(
          instance.connect(addr1).startSale(5,0)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("Invalid arguments", async function () {
        await expect(
          instance.startSale(0, 0)
        ).to.be.revertedWith("Invalid maxNbrTokenClaimable");
        await expect(
          instance.startSale(tokenMaxSupply, 0)
        ).to.be.revertedWith("Invalid maxNbrTokenClaimable");
        // If no whitelist then no whitelisted only period
        await expect(
          instance.startSale(maxTokensClaimable, 3600)
        ).to.be.revertedWith("Invalid duration - WHList empty");
        // If whitelist not empty then whitelisted period must exist but lower than max security
        await instance.startPresale();
        await instance.addToWhitelist([addr1.address, addr2.address]);
        await expect(
          instance.startSale(maxTokensClaimable, 0)
        ).to.be.revertedWith("Invalid duration - too long");
        await expect(
          instance.startSale(maxTokensClaimable, 800000)
        ).to.be.revertedWith("Invalid duration - too long");        
      });

      it("Proper initialization of sale period without presale periode", async function () {
        await instance.startSale(maxTokensClaimable, 0);
        expect(await instance.currentPeriod()).to.equal(2);
        expect(await instance.whitelistOnlySaleEndTimestamp()).to.equal(0);
      });
      
      it("Proper initialization of sale period with presale periode", async function () {
        await instance.startPresale();
        await instance.addToWhitelist([addr1.address, addr2.address]);
        await instance.startSale(maxTokensClaimable, 3600);
        expect(await instance.currentPeriod()).to.equal(2);
        expect(await instance.whitelistOnlySaleEndTimestamp()).to.gt(0);
      });
  });

  describe("Claiming tokens", function () {

      it("If not owner, user must wait for sale period to begin", async function () {
        await expect(
          instance.connect(addr1).claim(1)
        ).to.be.revertedWith("Sale period not opened");
      });

      it("If not owner, user must be whitelisted during whitelisted reserved sale period", async function () {
        await instance.startPresale();
        await instance.addToWhitelist([addr2.address]);
        await instance.startSale(maxTokensClaimable, 3600);
        await expect(
          instance.connect(addr1).claim(1)
        ).to.be.revertedWith("Address not found in whitelist");
      });

      it("Claim between 1 and maxTokensClaimable", async function () {
        await expect(
          instance.claim(0)
        ).to.be.revertedWith("Request at least 1 token");
        await instance.startSale(maxTokensClaimable, 0);
        await expect(
          instance.connect(addr1).claim(maxTokensClaimable + 1)
        ).to.be.revertedWith("Too many tokens claimed");
        // TODO if 2 tc cumul
      });

      it("Provid enough ETH for claiming when price > 0", async function () {
        await instance.startSale(maxTokensClaimable, 0);
        // Value = 0
        await expect(
          instance.connect(addr1).claim(1)
        ).to.be.revertedWith("Ether value sent is not enough");
        // value < cost
        await expect(
          instance.connect(addr1).claim(2, {value: ((tokenPrice * 2) - 1000000).toString()})
        ).to.be.revertedWith("Ether value sent is not enough");
      });

      /*
      it("Should fail when above maxSupply", async function () {
        await expect(
          instance.claim(tokenMaxSupply + 1)
        ).to.be.revertedWith("Invalid token Id");
      });
  */
      
      it("When new tokens are minted by owner, no value needed and totalSupply should increase by nbr of token minted as well as user balance", async function () {
        // Check event at the same time
        await expect(instance.claim(1)).to.emit(instance, 'TokenClaimed').withArgs(owner.address, 0);
        expect(await instance.totalSupply()).to.equal(1);
        expect(await instance.balanceOf(owner.address)).to.equal(1);
      });

      it("When new tokens are minted by user, value should be enough and totalSupply should increase by nbr of token minted as well as user balance", async function () {
        const nbr = 2;
        const amount = (tokenPrice * nbr).toString();
        await instance.startSale(maxTokensClaimable, 0);
        await instance.connect(addr1).claim(2, {value: amount});
        expect(await instance.totalSupply()).to.equal(nbr);
        expect(await instance.balanceOf(addr1.address)).to.equal(nbr);
        // Contract balance increased
        expect(await ethers.provider.getBalance(instance.address)).to.equal(amount);
        // console.log(ethers.utils.formatEther(amount));
      });


      
   });
    

    /*
    it("When sales ended, no more claim allowed"), async function () {
      // TODO
    });
    */

    /*
  describe("Aftersale period", function () {

    it("Should fail when token is claimed", async function () {
      await expect(
        instance.claim(tokenMaxSupply + 1)
      ).to.be.revertedWith("Invalid token Id");
    });
  });
  */

});
