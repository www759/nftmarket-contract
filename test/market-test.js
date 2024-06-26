const {expect} = require("chai");
const {ethers} = require("hardhat");

describe('NftMarket', async function() {
    let erc20, nft, market, accountA, accountB;
    const erc20Num = "1000000000000000000000000";
    // A: seller B: buyer
    beforeEach(async() => {
        [accountA, accountB] = await ethers.getSigners();
        let ERC20 = await ethers.getContractFactory('FToken');
        erc20 = await ERC20.deploy(accountA.address);
        let NFT = await ethers.getContractFactory('FNFT');
        nft = await NFT.deploy();
        let MARKET = await ethers.getContractFactory('Market');
        market = await MARKET.deploy(erc20.target);

        await erc20.mint(accountB.address, erc20Num);
        await erc20.connect(accountB).approve(market.target, erc20Num);
        await nft.safeMint(accountA, "0");
        await nft.safeMint(accountA, "1");
        await nft.safeMint(accountA, "2");
        await nft.setApprovalForAll(market.target, true);
    })

    it("erc20 check", async () => {
        expect(await erc20.decimals()).to.equal(18);

        expect(await erc20.balanceOf(accountA.address)).to.equal(erc20Num);
        expect(await erc20.balanceOf(accountB.address)).to.equal(erc20Num);

        expect(await erc20.allowance(accountB.address, market)).to.equal(erc20Num);
    })

    it("nft check", async () => {
        expect(await nft.isApprovedForAll(accountA.address, market)).to.equal(true);

        expect(await nft.balanceOf(accountA.address)).to.equal(3);
        
        expect(await nft.tokenURI(0)).to.equal("0");
        expect(await nft.tokenURI(1)).to.equal("1");
        expect(await nft.tokenURI(2)).to.equal("2");

    })
    

    it("market owner and erc20 address check", async () => {
        expect(await market.marketOwner()).to.equal(accountA);

        expect(await market.erc20()).to.equal(erc20.target);
    })


    it("market func check", async() => {
        const price = "1000000000000000000000";
        const newPrice = "1230000000000000000000";

        // list
        expect(await market.listNFT(nft.target, 0, price)).to.emit(market, "NewOrder");
        expect(await market.listNFT(nft.target, 1, price)).to.emit(market, "NewOrder");
        expect(await market.listNFT(nft.target, 2, price)).to.emit(market, "NewOrder");

        
        // isListed
        expect(await market.isListed(nft.target, 0)).to.equal(true);
        expect(await market.isListed(nft.target, 1)).to.equal(true);
        expect(await market.isListed(nft.target, 2)).to.equal(true);

        // getAll
        expect((await market.getAllOrders(nft.target)).length).to.equal(3);
        
        // unlist
        expect(await market.getOrderLength(nft.target)).to.equal(3);
        expect(await market.unlistNFT(nft.target, 1)).to.emit(market, "OrderCanceled");
        expect(await market.getOrderLength(nft.target)).to.equal(2);
        expect(await market.tokenIdToIndex(nft.target, 2)).to.equal(1);
        

        // changePrice
        expect(await market.changePrice(nft.target, 2, newPrice)).to.emit(market, "PriceChanged");
        expect((await market.orderOfTokenId(nft.target, 2))[3]).to.equal(newPrice);

        // buy
        expect((await market.connect(accountB).buy(nft.target, 0))).to.emit(market, "Deal");
        expect(await market.getOrderLength(nft.target)).to.equal(1);
        expect(await nft.ownerOf(0)).equal(accountB.address);
    })


})