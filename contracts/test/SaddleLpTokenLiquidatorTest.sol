// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { SaddleLpTokenLiquidator } from "../liquidators/SaddleLpTokenLiquidator.sol";
import { SaddleLpPriceOracle } from "../oracles/default/SaddleLpPriceOracle.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract SaddleLpTokenLiquidatorTest is BaseTest {
  SaddleLpTokenLiquidator private liquidator;
  SaddleLpPriceOracle oracle;
  address fraxUsdc_lp = 0x896935B02D3cBEb152192774e4F1991bb1D2ED3f;

  function afterForkSetUp() internal override {
    liquidator = new SaddleLpTokenLiquidator();
    oracle = SaddleLpPriceOracle(0x00126A44a03aE8e7A63c736Db608BD0d9F4e97bf);
  }

  function testSaddleLpTokenLiquidator() public fork(ARBITRUM_ONE) {
    IERC20Upgradeable lpToken = IERC20Upgradeable(fraxUsdc_lp);
    address lpTokenWhale = 0xa5bD85ed9fA27ba23BfB702989e7218E44fd4706; // metaswap
    bytes memory data = abi.encode(0, address(oracle));
    uint256 amount = 1e18;

    address pool = oracle.poolOf(address(lpToken));
    vm.prank(lpTokenWhale);
    lpToken.transfer(address(liquidator), 1e18);

    vm.prank(address(liquidator));
    lpToken.approve(pool, 1e18);
    liquidator.redeem(lpToken, amount, data);
  }
}
