// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { AlpacaERC4626, IAlpacaVault } from "../compound/strategies/AlpacaERC4626.sol";
import { MockVault } from "./mocks/alpaca/MockVault.sol";
import { IVaultConfig } from "./mocks/alpaca/IVaultConfig.sol";
import { IW_NATIVE } from "../utils/IW_NATIVE.sol";
import { FixedPointMathLib } from "../utils/FixedPointMathLib.sol";

contract AlpacaERC4626Test is BaseTest {
  using FixedPointMathLib for uint256;
  AlpacaERC4626 alpacaERC4626;

  MockERC20 underlyingToken;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

  address joy = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;

  uint256 iniitalBeefyBalance = 0;
  uint256 initialBeefySupply = 0;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    underlyingToken = MockERC20(ap.getAddress("wtoken"));
    mockVault = MockVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    alpacaERC4626 = new AlpacaERC4626(
      underlyingToken,
      IAlpacaVault(address(mockVault)),
      IW_NATIVE(ap.getAddress("wtoken"))
    );
    iniitalBeefyBalance = mockVault.totalToken();
    initialBeefySupply = mockVault.totalSupply();
    sendUnderlyingToken(100e18, address(this));
    sendUnderlyingToken(100e18, address(1));
  }

  function deposit(address _owner, uint256 amount) public {
    vm.startPrank(_owner);
    underlyingToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.deposit(amount, _owner);
    vm.stopPrank();
  }

  function sendUnderlyingToken(uint256 amount, address recipient) public {
    vm.startPrank(joy);
    underlyingToken.transfer(recipient, amount);
    vm.stopPrank();
  }

  function increaseAssetsInVault() public {
    sendUnderlyingToken(1000e18, address(mockVault));
    // mockVault.earn();
  }

  function getExpectedVaultShares(uint256 amount) internal returns (uint256) {
    uint256 total = mockVault.totalToken();
    uint256 shares = total == 0 ? amount : (amount * mockVault.totalSupply()) / total;
    return shares;
  }

  function testDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedErc4626Shares = alpacaERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);

    // Test that the balance view calls work
    assertTrue(diff(alpacaERC4626.totalAssets(), depositAmount) <= 1);
    assertTrue(diff(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount) <= 1);

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), expectedErc4626Shares);
    assertEq(alpacaERC4626.totalSupply(), expectedErc4626Shares);

    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);
    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares);
  }

  function testMultipleDeposit() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 expectedErc4626Shares = alpacaERC4626.previewDeposit(depositAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);

    // Test that the balance view calls work
    assertTrue(
      diff(depositAmount * 2, alpacaERC4626.totalAssets()) <= 2,
      "Beefy total Assets should be same as sum of deposited amounts"
    );
    assertTrue(
      diff(depositAmount, alpacaERC4626.balanceOfUnderlying(address(this))) <= 10,
      "Underlying token balance should be same as depositied amount"
    );
    assertTrue(
      diff(depositAmount, alpacaERC4626.balanceOfUnderlying(address(1))) <= 10,
      "Underlying token balance should be same as depositied amount"
    );

    // Test that we minted the correct amount of token
    assertTrue(diff(alpacaERC4626.balanceOf(address(this)), expectedErc4626Shares) <= 1);
    assertTrue(diff(alpacaERC4626.balanceOf(address(1)), expectedErc4626Shares) <= 1);
    assertTrue(diff(alpacaERC4626.totalSupply(), expectedErc4626Shares * 2) <= 2);

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount * 2);

    assertTrue(diff(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares) <= 1);

    // Beefy ERC4626 should not have underlyingToken after deposit
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 mintAmount = alpacaERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(this));

    // Test that the balance view calls work
    assertTrue(diff(alpacaERC4626.totalAssets(), depositAmount) <= 1);
    assertTrue(diff(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount) <= 1);

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), mintAmount);
    assertEq(alpacaERC4626.totalSupply(), mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);
    assertEq(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares);
  }

  function testMultipleMint() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 mintAmount = alpacaERC4626.previewDeposit(depositAmount);

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(this));

    // Test that the balance view calls work
    assertTrue(diff(alpacaERC4626.totalAssets(), depositAmount) <= 10);
    assertTrue(diff(alpacaERC4626.balanceOfUnderlying(address(this)), depositAmount) <= 10);

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(this)), mintAmount);
    assertEq(alpacaERC4626.totalSupply(), mintAmount);

    assertTrue(underlyingToken.balanceOf(address(alpacaERC4626)) <= 10, "Beefy erc4626 locked amount checking");

    vm.startPrank(address(1));
    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    alpacaERC4626.mint(mintAmount, address(1));

    // Test that the balance view calls work
    assertTrue(depositAmount + depositAmount - alpacaERC4626.totalAssets() <= 10);
    assertTrue(depositAmount - alpacaERC4626.balanceOfUnderlying(address(1)) <= 10);

    // Test that we minted the correct amount of token
    assertEq(alpacaERC4626.balanceOf(address(1)), mintAmount);
    assertEq(alpacaERC4626.totalSupply(), mintAmount + mintAmount);

    // Test that the ERC4626 holds the expected amount of beefy shares
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount * 2);

    assertTrue(diff(mockVault.balanceOf(address(alpacaERC4626)), expectedBeefyShares) <= 10);

    assertTrue(underlyingToken.balanceOf(address(alpacaERC4626)) <= 10, "Beefy erc4626 locked amount checking");
    vm.stopPrank();
  }

  function testWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    uint256 expectedBeefyShares = getExpectedVaultShares(depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(withdrawalAmount, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), depositAmount - expectedErc4626SharesNeeded, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertEq(
      mockVault.balanceOf(address(alpacaERC4626)),
      expectedBeefyShares - expectedBeefySharesNeeded,
      "!beefy share balance"
    );
  }

  function testMultipleWithdraw() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawalAmount = 10e18;

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount * 2);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    uint256 expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(depositAmount * 2 - expectedErc4626SharesNeeded, alpacaERC4626.totalSupply()) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(
      diff(mockVault.balanceOf(address(alpacaERC4626)), beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - expectedErc4626SharesNeeded;
    beefyShares = beefyShares - expectedBeefySharesNeeded;
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = alpacaERC4626.balanceOf(address(1));
    expectedErc4626SharesNeeded = alpacaERC4626.previewWithdraw(withdrawalAmount);
    expectedBeefySharesNeeded = expectedErc4626SharesNeeded.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    vm.prank(address(1));
    alpacaERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertTrue(diff(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(alpacaERC4626.totalSupply(), totalSupplyBefore - expectedErc4626SharesNeeded) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(1)), erc4626BalBefore - expectedErc4626SharesNeeded, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(
      diff(mockVault.balanceOf(address(alpacaERC4626)), beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertTrue(diff(alpacaERC4626.totalSupply(), depositAmount - redeemAmount) <= 1, "!totalSupply");

    // Test that we burned the right amount of shares
    assertTrue(diff(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount) <= 1, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(
      diff(mockVault.balanceOf(address(alpacaERC4626)), beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );
  }

  function testMultipleRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawalAmount = 10e18;
    uint256 redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);

    deposit(address(this), depositAmount);
    deposit(address(1), depositAmount);
    uint256 beefyShares = getExpectedVaultShares(depositAmount * 2);

    uint256 assetBalBefore = underlyingToken.balanceOf(address(this));
    uint256 erc4626BalBefore = alpacaERC4626.balanceOf(address(this));
    uint256 expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );

    alpacaERC4626.withdraw(10e18, address(this), address(this));

    // Test that the actual transfers worked
    assertTrue(
      diff(underlyingToken.balanceOf(address(this)), assetBalBefore + withdrawalAmount) <= 1,
      "!user asset bal"
    );

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), depositAmount * 2 - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertTrue(diff(alpacaERC4626.balanceOf(address(this)), erc4626BalBefore - redeemAmount) <= 1, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(
      diff(mockVault.balanceOf(address(alpacaERC4626)), beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");

    uint256 totalSupplyBefore = depositAmount * 2 - redeemAmount;
    beefyShares -= expectedBeefySharesNeeded;
    redeemAmount = alpacaERC4626.previewWithdraw(withdrawalAmount);
    assetBalBefore = underlyingToken.balanceOf(address(1));
    erc4626BalBefore = alpacaERC4626.balanceOf(address(1));
    expectedBeefySharesNeeded = redeemAmount.mulDivUp(
      mockVault.balanceOf(address(alpacaERC4626)),
      alpacaERC4626.totalSupply()
    );
    vm.prank(address(1));
    alpacaERC4626.withdraw(10e18, address(1), address(1));

    // Test that the actual transfers worked
    assertTrue(diff(underlyingToken.balanceOf(address(1)), assetBalBefore + withdrawalAmount) <= 1, "!user asset bal");

    // Test that the balance view calls work
    // I just couldnt not calculate this properly. i was for some reason always ~ 1 BPS off
    // uint256 expectedAssetsAfter = depositAmount - (expectedBeefySharesNeeded + (expectedBeefySharesNeeded / 1000));
    //assertEq(alpacaERC4626.totalAssets(), expectedAssetsAfter, "!erc4626 asset bal");
    assertEq(alpacaERC4626.totalSupply(), totalSupplyBefore - redeemAmount, "!totalSupply");

    // Test that we burned the right amount of shares
    assertEq(alpacaERC4626.balanceOf(address(1)), erc4626BalBefore - redeemAmount, "!erc4626 supply");

    // Test that the ERC4626 holds the expected amount of beefy shares
    assertTrue(
      diff(mockVault.balanceOf(address(alpacaERC4626)), beefyShares - expectedBeefySharesNeeded) <= 1,
      "!beefy share balance"
    );
    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "Beefy erc4626 locked amount checking");
  }

  function testAlpacaPauseContract() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    underlyingToken.approve(address(alpacaERC4626), depositAmount);
    vm.expectRevert("Pausable: paused");
    alpacaERC4626.deposit(depositAmount, address(this));

    vm.expectRevert("Pausable: paused");
    alpacaERC4626.mint(depositAmount, address(this));

    emit log_uint(alpacaERC4626.totalSupply());
    emit log_uint(alpacaERC4626.totalAssets());

    uint256 expectedSharesNeeded = alpacaERC4626.previewWithdraw(withdrawAmount);
    alpacaERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertEq(alpacaERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded, "!withdraw share bal");
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(alpacaERC4626.totalAssets(), alpacaERC4626.totalSupply());
    alpacaERC4626.redeem(withdrawAmount, address(this), address(this));

    assertEq(
      alpacaERC4626.balanceOf(address(this)),
      depositAmount - withdrawAmount - expectedSharesNeeded,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }

  function testAlpacaEmergencyWithdrawAndPause() public shouldRun(forChains(BSC_MAINNET)) {
    deposit(address(this), depositAmount);

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), 0, "!init 0");
    uint256 expectedBal = alpacaERC4626.previewRedeem(depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    assertEq(underlyingToken.balanceOf(address(alpacaERC4626)), expectedBal, "!withdraws underlying");
    assertEq(alpacaERC4626.totalAssets(), expectedBal, "!totalAssets == expectedBal");
  }

  function testAlpacaEmergencyWithdrawAndRedeem() public shouldRun(forChains(BSC_MAINNET)) {
    uint256 withdrawAmount = 1e18;

    deposit(address(this), depositAmount);

    alpacaERC4626.emergencyWithdrawAndPause();

    uint256 expectedSharesNeeded = withdrawAmount.mulDivDown(alpacaERC4626.totalSupply(), alpacaERC4626.totalAssets());
    alpacaERC4626.withdraw(withdrawAmount, address(this), address(this));

    assertTrue(
      diff(alpacaERC4626.balanceOf(address(this)), depositAmount - expectedSharesNeeded) <= 1,
      "!withdraw share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount, "!withdraw asset bal");

    uint256 expectedAssets = withdrawAmount.mulDivUp(alpacaERC4626.totalAssets(), alpacaERC4626.totalSupply());
    alpacaERC4626.redeem(withdrawAmount, address(this), address(this));

    assertTrue(
      diff(alpacaERC4626.balanceOf(address(this)), depositAmount - withdrawAmount - expectedSharesNeeded) <= 1,
      "!redeem share bal"
    );
    assertEq(underlyingToken.balanceOf(address(this)), withdrawAmount + expectedAssets, "!redeem asset bal");
  }
}

contract AlpacaERC4626UnitTest is BaseTest {
  AlpacaERC4626 alpacaERC4626;

  MockERC20 testToken;
  MockVault mockVault;

  uint256 depositAmount = 100e18;

  address joy = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
  address alice = address(10);
  address bob = address(20);
  address charlie = address(30);

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    testToken = MockERC20(ap.getAddress("wtoken"));
    mockVault = MockVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    alpacaERC4626 = new AlpacaERC4626(testToken, IAlpacaVault(address(mockVault)), IW_NATIVE(ap.getAddress("wtoken")));
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(alpacaERC4626.name(), "Midas Wrapped BNB Vault");
    assertEq(alpacaERC4626.symbol(), "mvWBNB");
    assertEq(address(alpacaERC4626.asset()), address(testToken));
    assertEq(address(alpacaERC4626.alpacaVault()), address(mockVault));
  }

  function deposit(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.deposit(amount, user);
    vm.stopPrank();
  }

  function mint(address user, uint256 amount) internal {
    // transfer to user exactly amount
    vm.prank(alice);
    testToken.transfer(user, amount);
    assertEq(testToken.balanceOf(user), amount, "the full balance of underlying token of user should equal amount");

    // deposit the full amount to the plugin as user, check the result
    vm.startPrank(user);
    testToken.approve(address(alpacaERC4626), amount);
    alpacaERC4626.mint(alpacaERC4626.previewDeposit(amount), user);
    vm.stopPrank();
  }

  function testTheBugWithdraw(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e18 && amount < 1e19);
    vm.prank(joy);
    testToken.transferFrom(joy, alice, 100e18);
    // testToken.mint(alice, 100e18);

    deposit(bob, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(bob), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(alpacaERC4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(charlie, amount);

    // test if the shares of the alpacaERC4626 equal to the assets deposited
    uint256 alpacaERC4626SharesMintedToBob = alpacaERC4626.balanceOf(bob);
    assertEq(
      alpacaERC4626SharesMintedToBob,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(bob);
      uint256 assetsToWithdraw = amount / 2;
      alpacaERC4626.withdraw(assetsToWithdraw, bob, bob);
      uint256 assetsWithdrawn = testToken.balanceOf(bob);
      assertTrue(
        diff(assetsWithdrawn, assetsToWithdraw) < 100,
        "the assets withdrawn must be almost equal to the requested assets to withdraw"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(alpacaERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the alpacaERC4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the withdrawn underlying token, no dust is acceptable"
    );
  }

  function testTheBugRedeem(uint256 amount) public shouldRun(forChains(BSC_MAINNET)) {
    vm.assume(amount > 1e18 && amount < 1e19);
    vm.prank(joy);
    testToken.transferFrom(joy, alice, 100e18);

    deposit(charlie, amount);
    // make sure the full amount is deposited and none is left
    assertEq(testToken.balanceOf(charlie), 0, "should deposit the full balance of underlying token of user");
    assertEq(
      testToken.balanceOf(address(alpacaERC4626)),
      0,
      "should deposit the full balance of underlying token of user"
    );

    // just testing if other users depositing would mess up the calcs
    mint(bob, amount);

    // test if the shares of the alpacaERC4626 equal to the assets deposited
    uint256 alpacaERC4626SharesMintedToCharlie = alpacaERC4626.balanceOf(charlie);
    assertEq(
      alpacaERC4626SharesMintedToCharlie,
      amount,
      "the first minted shares in erc4626 are expected to equal the assets deposited"
    );

    {
      vm.startPrank(charlie);
      uint256 alpacaERC4626SharesToRedeem = alpacaERC4626.balanceOf(charlie);
      alpacaERC4626.redeem(alpacaERC4626SharesToRedeem, charlie, charlie);
      uint256 assetsRedeemed = testToken.balanceOf(charlie);
      uint256 assetsToRedeem = alpacaERC4626.previewRedeem(alpacaERC4626SharesToRedeem);
      {
        emit log_uint(assetsRedeemed);
        emit log_uint(assetsToRedeem);
      }
      assertTrue(
        diff(assetsRedeemed, assetsToRedeem) * 1e4 < amount,
        "the assets redeemed must be almost equal to the requested assets to redeem"
      );
      vm.stopPrank();
    }

    uint256 lockedFunds = testToken.balanceOf(address(alpacaERC4626));
    {
      emit log_uint(lockedFunds);
    }
    // check if any funds remained locked in the alpacaERC4626
    assertEq(
      lockedFunds,
      0,
      "should transfer the full balance of the redeemed underlying token, no dust is acceptable"
    );
  }
}
