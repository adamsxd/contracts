// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";

import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { MidasFlywheelCore } from "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { MidasReplacingFlywheel } from "../midas/strategies/flywheel/MidasReplacingFlywheel.sol";
import { ReplacingFlywheelDynamicRewards } from "../midas/strategies/flywheel/rewards/ReplacingFlywheelDynamicRewards.sol";
import { MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import { CErc20PluginRewardsDelegate } from "../compound/CErc20PluginRewardsDelegate.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IFlywheelRewards } from "flywheel-v2/interfaces/IFlywheelRewards.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FlywheelDynamicRewards } from "flywheel-v2/rewards/FlywheelDynamicRewards.sol";

contract FlywheelUpgradesTest is BaseTest {
  FusePoolDirectory internal fpd;

  function afterForkSetUp() internal override {
    fpd = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testFlywheelUpgradeBsc() public debuggingOnly fork(BSC_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradePolygon() public debuggingOnly fork(POLYGON_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeMoonbeam() public debuggingOnly fork(MOONBEAM_MAINNET) {
    _testFlywheelUpgrade();
  }

  function testFlywheelUpgradeEvmos() public debuggingOnly fork(EVMOS_MAINNET) {
    _testFlywheelUpgrade();
  }

  function _testFlywheelUpgrade() internal {
    MidasFlywheelCore newImpl = new MidasFlywheelCore();

    (, FusePoolDirectory.FusePool[] memory pools) = fpd.getActivePools();

    for (uint8 i = 0; i < pools.length; i++) {
      IComptroller pool = IComptroller(pools[i].comptroller);

      ICToken[] memory markets = pool.getAllMarkets();

      address[] memory flywheels = pool.getRewardsDistributors();
      if (flywheels.length > 0) {
        emit log("");
        emit log_named_address("pool", address(pool));
      }
      for (uint8 j = 0; j < flywheels.length; j++) {
        MidasFlywheelCore flywheel = MidasFlywheelCore(flywheels[j]);

        // upgrade
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(flywheels[j]));
        bytes32 bytesAtSlot = vm.load(address(proxy), _ADMIN_SLOT);
        address admin = address(uint160(uint256(bytesAtSlot)));

        if (admin != address(0)) {
          vm.prank(admin);
          proxy.upgradeTo(address(newImpl));
          emit log_named_address("upgradable flywheel", address(flywheel));

          bool anyStrategyHasPositiveIndex = false;

          for (uint8 k = 0; k < markets.length; k++) {
            ERC20 strategy = ERC20(address(markets[k]));
            (uint224 index, uint32 ts) = flywheel.strategyState(strategy);
            if (index > 0) {
              anyStrategyHasPositiveIndex = true;
              break;
            }
          }

          if (!anyStrategyHasPositiveIndex)
            emit log_named_address("all zero index strategies flywheel", address(flywheel));
          //assertTrue(anyStrategyHasPositiveIndex, "!flywheel has no strategies added or is broken");
        } else {
          //assertTrue(false, "flywheel proxy admin 0");
          emit log_named_address("not upgradable flywheel", address(flywheel));
        }
      }
    }
  }

  function test2BrlFlywheelReplacement() public debuggingOnly fork(BSC_MAINNET) {
    CErc20PluginRewardsDelegate market = CErc20PluginRewardsDelegate(0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba); // 2brl market
    ERC20 strategy = ERC20(address(market));
    address user = 0xC3A9b350eBBCDD14B96934B6831f1978431D9B8c;
    address flywheelAddress = 0xC6431455AeE17a08D6409BdFB18c4bc73a4069E4; // non-upgradable
    MidasFlywheelCore epxFlywheel = MidasFlywheelCore(flywheelAddress);
    address formerOwner = epxFlywheel.owner();
    FlywheelDynamicRewards oldRewards = FlywheelDynamicRewards(address(epxFlywheel.flywheelRewards()));

    MidasReplacingFlywheel impl = new MidasReplacingFlywheel();
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(formerOwner), "");
    MidasReplacingFlywheel replacingFlywheel = MidasReplacingFlywheel(address(proxy));
    replacingFlywheel.initialize(
      epxFlywheel.rewardToken(),
      IFlywheelRewards(address(0)),
      epxFlywheel.flywheelBooster(),
      address(this)
    );
    replacingFlywheel.reinitialize(epxFlywheel);

    ReplacingFlywheelDynamicRewards replacingRewards = new ReplacingFlywheelDynamicRewards(
      FlywheelCore(address(epxFlywheel)),
      FlywheelCore(address(replacingFlywheel)),
      oldRewards.rewardsCycleLength()
    );
    vm.prank(formerOwner);
    epxFlywheel.setFlywheelRewards(replacingRewards);
    vm.prank(replacingFlywheel.owner());
    replacingFlywheel.setFlywheelRewards(replacingRewards);

    uint256 oldFlywheelUserIndex = epxFlywheel.userIndex(strategy, user);
    uint256 newFlywheelUserIndex = replacingFlywheel.userIndex(strategy, user);

    assertGt(oldFlywheelUserIndex, 0, "needs a positive index for the check");
    assertEq(oldFlywheelUserIndex, newFlywheelUserIndex, "index replicated");
  }
}