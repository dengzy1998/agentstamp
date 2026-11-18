const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const DAY = 86400; // seconds

describe("AgentStamp", function () {
  let mock, stamp, holder, nonHolder, other;

  beforeEach(async function () {
    [, holder, nonHolder, other] = await ethers.getSigners();

    const Mock = await ethers.getContractFactory("MockAgentID");
    mock = await Mock.deploy();

    const Stamp = await ethers.getContractFactory("AgentStamp");
    stamp = await Stamp.deploy(await mock.getAddress());

    // `holder` owns a (mock) Agent ID; `nonHolder` and `other` do not.
    await mock.mint(holder.address);
  });

  async function checkInOnNextDay(signer) {
    await time.increase(DAY);
    return stamp.connect(signer).checkIn();
  }

  it("rejects deployment with a zero Agent ID address", async function () {
    const Stamp = await ethers.getContractFactory("AgentStamp");
    await expect(Stamp.deploy(ethers.ZeroAddress)).to.be.revertedWith(
      "AgentStamp: zero address"
    );
  });

  it("non-holder cannot check in", async function () {
    await expect(stamp.connect(nonHolder).checkIn()).to.be.revertedWith(
      "AgentStamp: no Agent ID"
    );
    const stats = await stamp.getStats(nonHolder.address);
    expect(stats.totalCheckins).to.equal(0);
  });

  it("holder can check in once per day, and not twice on the same day", async function () {
    const tx = await stamp.connect(holder).checkIn();
    const receipt = await tx.wait();
    const block = await ethers.provider.getBlock(receipt.blockNumber);
    const today = Math.floor(block.timestamp / DAY);

    await expect(tx)
      .to.emit(stamp, "CheckIn")
      .withArgs(holder.address, today, 1, 1);

    let stats = await stamp.getStats(holder.address);
    expect(stats.totalCheckins).to.equal(1);
    expect(stats.currentStreak).to.equal(1);
    expect(stats.lastCheckinDay).to.equal(today);

    await expect(stamp.connect(holder).checkIn()).to.be.revertedWith(
      "AgentStamp: already checked in today"
    );

    stats = await stamp.getStats(holder.address);
    expect(stats.totalCheckins).to.equal(1);
  });

  it("streak increments across consecutive simulated days", async function () {
    await stamp.connect(holder).checkIn(); // day 0: total 1, streak 1
    await checkInOnNextDay(holder); //        day 1: total 2, streak 2
    await checkInOnNextDay(holder); //        day 2: total 3, streak 3

    const stats = await stamp.getStats(holder.address);
    expect(stats.totalCheckins).to.equal(3);
    expect(stats.currentStreak).to.equal(3);
  });

  it("streak resets after a missed day", async function () {
    await stamp.connect(holder).checkIn(); // day 0: streak 1
    await time.increase(2 * DAY); // skip a whole day
    await stamp.connect(holder).checkIn(); // streak restarts

    let stats = await stamp.getStats(holder.address);
    expect(stats.totalCheckins).to.equal(2);
    expect(stats.currentStreak).to.equal(1);

    // After another full missed day, the effective streak reads 0.
    await time.increase(2 * DAY);
    stats = await stamp.getStats(holder.address);
    expect(stats.currentStreak).to.equal(0);
    expect(stats.totalCheckins).to.equal(2);
  });

  it("mints the first badge exactly at total 3, and not before", async function () {
    await stamp.connect(holder).checkIn(); // total 1
    await checkInOnNextDay(holder); //        total 2

    expect(await stamp.hasBadge(holder.address, 0)).to.equal(false);
    expect(await stamp.balanceOf(holder.address)).to.equal(0);

    const tx = await checkInOnNextDay(holder); // total 3 -> badge
    const badgeId = await stamp.badgeTokenId(holder.address, 0);
    await expect(tx)
      .to.emit(stamp, "BadgeMinted")
      .withArgs(holder.address, 3, badgeId);
    await expect(tx)
      .to.emit(stamp, "Transfer")
      .withArgs(ethers.ZeroAddress, holder.address, badgeId);

    expect(await stamp.hasBadge(holder.address, 0)).to.equal(true);
    expect(await stamp.balanceOf(holder.address)).to.equal(1);
    expect(await stamp.ownerOf(badgeId)).to.equal(holder.address);
    // The 7-check-in badge must NOT exist yet.
    expect(await stamp.hasBadge(holder.address, 1)).to.equal(false);
  });

  it("mints the second badge exactly at total 7", async function () {
    await stamp.connect(holder).checkIn(); // total 1
    for (let i = 0; i < 5; i++) {
      await checkInOnNextDay(holder); // totals 2..6
    }
    expect(await stamp.balanceOf(holder.address)).to.equal(1); // only badge 3

    const tx = await checkInOnNextDay(holder); // total 7 -> badge
    const badgeId = await stamp.badgeTokenId(holder.address, 1);
    await expect(tx)
      .to.emit(stamp, "BadgeMinted")
      .withArgs(holder.address, 7, badgeId);

    expect(await stamp.hasBadge(holder.address, 1)).to.equal(true);
    expect(await stamp.balanceOf(holder.address)).to.equal(2);
    expect(await stamp.ownerOf(badgeId)).to.equal(holder.address);
    // Later milestones not yet earned.
    expect(await stamp.hasBadge(holder.address, 2)).to.equal(false);

    const stats = await stamp.getStats(holder.address);
    expect(stats.totalCheckins).to.equal(7);
    expect(stats.currentStreak).to.equal(7);
    expect(stats.badgesMask).to.equal(0b00011);
  });

  it("badges are soulbound: transfers and approvals revert", async function () {
    await stamp.connect(holder).checkIn();
    await checkInOnNextDay(holder);
    await checkInOnNextDay(holder); // total 3 -> badge minted
    const badgeId = await stamp.badgeTokenId(holder.address, 0);

    await expect(
      stamp.connect(holder).transferFrom(holder.address, other.address, badgeId)
    ).to.be.revertedWith("AgentStamp: soulbound, non-transferable");

    await expect(
      stamp
        .connect(holder)
        ["safeTransferFrom(address,address,uint256)"](holder.address, other.address, badgeId)
    ).to.be.revertedWith("AgentStamp: soulbound, non-transferable");

    await expect(
      stamp
        .connect(holder)
        ["safeTransferFrom(address,address,uint256,bytes)"](holder.address, other.address, badgeId, "0x")
    ).to.be.revertedWith("AgentStamp: soulbound, non-transferable");

    await expect(stamp.connect(holder).approve(other.address, badgeId)).to.be.revertedWith(
      "AgentStamp: soulbound, non-transferable"
    );

    await expect(
      stamp.connect(holder).setApprovalForAll(other.address, true)
    ).to.be.revertedWith("AgentStamp: soulbound, non-transferable");

    // Ownership is unchanged after all those attempts.
    expect(await stamp.ownerOf(badgeId)).to.equal(holder.address);
  });

  it("tokenURI returns on-chain JSON naming the milestone", async function () {
    await stamp.connect(holder).checkIn();
    await checkInOnNextDay(holder);
    await checkInOnNextDay(holder); // total 3 -> badge
    const badgeId = await stamp.badgeTokenId(holder.address, 0);

    const uri = await stamp.tokenURI(badgeId);
    const prefix = "data:application/json;base64,";
    expect(uri.startsWith(prefix)).to.equal(true);
    const json = JSON.parse(Buffer.from(uri.slice(prefix.length), "base64").toString("utf8"));
    expect(json.name).to.equal("AgentStamp Badge - 3 Check-ins");
    expect(json.attributes[0].trait_type).to.equal("Milestone (total check-ins)");
    expect(json.attributes[0].value).to.equal(3);

    // Nonexistent badge reverts.
    const fakeId = await stamp.badgeTokenId(holder.address, 4);
    await expect(stamp.tokenURI(fakeId)).to.be.revertedWith("AgentStamp: nonexistent token");
    await expect(stamp.ownerOf(fakeId)).to.be.revertedWith("AgentStamp: nonexistent token");
  });

  it("a second holder earns badges independently", async function () {
    await mock.mint(other.address);
    await stamp.connect(other).checkIn();
    await checkInOnNextDay(other);
    await checkInOnNextDay(other);

    expect(await stamp.balanceOf(other.address)).to.equal(1);
    expect(await stamp.balanceOf(holder.address)).to.equal(0);
    const stats = await stamp.getStats(other.address);
    expect(stats.totalCheckins).to.equal(3);
  });
});
