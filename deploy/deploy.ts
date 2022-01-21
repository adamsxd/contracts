import { constants } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { deploy1337 } from "../chainDeploy/1337";

const func: DeployFunction = async ({ ethers, getNamedAccounts, deployments, getChainId }): Promise<void> => {
  const { deployer, alice, bob } = await getNamedAccounts();

  ////
  //// COMPOUND CORE CONTRACTS
  let dep = await deployments.deterministic("Comptroller", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const comp = await dep.deploy();
  console.log("Comptroller: ", comp.address);

  dep = await deployments.deterministic("CErc20Delegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const erc20Del = await dep.deploy();
  console.log("CErc20Delegate: ", erc20Del.address);

  dep = await deployments.deterministic("CEtherDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ethDel = await dep.deploy();
  console.log("CEtherDelegate: ", ethDel.address);

  dep = await deployments.deterministic("RewardsDistributorDelegate", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const rewards = await dep.deploy();
  // const rewardsDistributorDelegate = await ethers.getContract("RewardsDistributorDelegate", deployer);
  // await rewardsDistributorDelegate.initialize(constants.AddressZero);
  console.log("RewardsDistributorDelegate: ", rewards.address);
  ////

  ////
  //// IRM MODELS
  //  https://etherscan.io/address/0xd956188795ca6F4A74092ddca33E0Ea4cA3a1395#code
  dep = await deployments.deterministic("JumpRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "180000000000000000", // multiplierPerYear
      "4000000000000000000", //jumpMultiplierPerYear
      "800000000000000000", // kink
    ],
    log: true,
  });

  const jrm = await dep.deploy();
  console.log("JumpRateModel: ", jrm.address);

  // taken from WhitePaperInterestRateModel used for cETH
  // https://etherscan.io/address/0x0c3f8df27e1a00b47653fde878d68d35f00714c0#code
  dep = await deployments.deterministic("WhitePaperInterestRateModel", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [
      "20000000000000000", // baseRatePerYear
      "100000000000000000", // multiplierPerYear
    ],
    log: true,
  });

  const wprm = await dep.deploy();
  console.log("WhitePaperInterestRateModel: ", wprm.address);
  ////

  ////
  //// FUSE CORE CONTRACTS
  dep = await deployments.deterministic("FusePoolDirectory", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpd = await dep.deploy();
  console.log("FusePoolDirectory: ", fpd.address);
  const fusePoolDirectory = await ethers.getContract("FusePoolDirectory", deployer);
  let tx = await fusePoolDirectory.initialize(true, [deployer, alice, bob]);
  await tx.wait();

  dep = await deployments.deterministic("FuseSafeLiquidator", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fsl = await dep.deploy();
  console.log("FuseSafeLiquidator: ", fsl.address);

  dep = await deployments.deterministic("FuseFeeDistributor", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ffd = await dep.deploy();
  console.log("FuseFeeDistributor: ", ffd.address);
  const fuseFeeDistributor = await ethers.getContract("FuseFeeDistributor", deployer);
  await fuseFeeDistributor.initialize(ethers.utils.parseEther("0.1"));
  await fuseFeeDistributor._setPoolLimits(
    ethers.utils.parseEther("1"),
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256
  );
  const comptroller = await ethers.getContract("Comptroller", deployer);
  tx = await fuseFeeDistributor._editComptrollerImplementationWhitelist(
    [constants.AddressZero],
    [comptroller.address],
    [true]
  );
  await tx.wait();

  dep = await deployments.deterministic("FusePoolLens", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpl = await dep.deploy();
  console.log("FusePoolLens: ", fpl.address);
  const fusePoolLens = await ethers.getContract("FusePoolLens", deployer);
  await fusePoolLens.initialize(fusePoolDirectory.address);

  dep = await deployments.deterministic("FusePoolLensSecondary", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const fpls = await dep.deploy();
  console.log("FusePoolLensSecondary: ", fpls.address);
  const fusePoolLensSecondary = await ethers.getContract("FusePoolLensSecondary", deployer);
  await fusePoolLensSecondary.initialize(fusePoolDirectory.address);

  const etherDelegate = await ethers.getContract("CEtherDelegate", deployer);
  const erc20Delegate = await ethers.getContract("CErc20Delegate", deployer);

  tx = await fuseFeeDistributor._editCEtherDelegateWhitelist(
    [constants.AddressZero],
    [etherDelegate.address],
    [false],
    [true]
  );

  let receipt = await tx.wait();
  console.log("Set whitelist for Ether Delegate with status:", receipt.status);

  tx = await fuseFeeDistributor._editCErc20DelegateWhitelist(
    [constants.AddressZero],
    [erc20Delegate.address],
    [false],
    [true]
  );
  receipt = await tx.wait();
  console.log("Set whitelist for ERC20 Delegate with status:", receipt.status);

  dep = await deployments.deterministic("InitializableClones", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const ic = await dep.deploy();
  console.log("InitializableClones: ", ic.address);
  ////

  ////
  //// ORACLES
  dep = await deployments.deterministic("MasterPriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const masterPO = await dep.deploy();
  console.log("MasterPriceOracle: ", masterPO.address);

  dep = await deployments.deterministic("ChainlinkPriceOracle", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [10],
    log: true,
  });
  const cpo = await dep.deploy();
  console.log("ChainlinkPriceOracle: ", cpo.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Root", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const utpor = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2Root: ", utpor.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [],
    log: true,
  });
  const utpo = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2: ", utpo.address);

  dep = await deployments.deterministic("UniswapTwapPriceOracleV2Factory", {
    from: deployer,
    salt: ethers.utils.keccak256(deployer),
    args: [utpor.address, utpo.address],
    log: true,
  });
  const utpof = await dep.deploy();
  console.log("UniswapTwapPriceOracleV2Factory: ", utpof.address);
  ////

  //// 
  //// CHAIN SPECIFIC DEPLOYMENT
  const chainId = await getChainId();
  console.log("Running deployment for chain: ", chainId);
  if (chainId === "1337") {
    await deploy1337({ethers, getNamedAccounts, deployments})
  }
  ////
};

export default func;
