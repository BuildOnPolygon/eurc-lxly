// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base, Events} from "../Base.sol";

contract MigrateFlows is Base {
    bytes private _emptyBytes;

    /// @notice Alice converts 1000 L2_WEURC to L2_EURC, then calls migrate,
    /// causing NativeConverter to bridge 1000 L2_WEURC, resulting in 1000
    /// L1_EURC being sent to L1Escrow.
    function testMigrateWithWEURC() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // Alice converts some wEURC to EURC
        // this causes L2_WEURC to be sent to NativeConverter
        uint256 amount = _toEURC(1000);
        uint256 balance1 = _erc20L2wEURC.balanceOf(_alice);
        uint256 wEURCSupply1 = _erc20L2wEURC.totalSupply();
        _erc20L2wEURC.approve(address(_nativeConverter), amount);
        _nativeConverter.convert(_alice, amount, _emptyBytes);

        // check that NativeConverter has the L2_BWEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent();

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Migrate(amount);

        // migrate all of the L2_BWEURC to L1
        vm.startPrank(_owner);
        _nativeConverter.migrate();
        vm.stopPrank();

        vm.startPrank(_alice);

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2Fork, _l1Fork);

        // check alice no longer has the L2_WEURC
        vm.selectFork(_l2Fork);
        uint256 balance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // // check that the supply of L2_WEURC decreased
        // uint256 wEURCSupply2 = _erc20L2wEURC.totalSupply();
        // assertEq(wEURCSupply1 - wEURCSupply2, amount);

        // check nativeconverter no longer has L2_WEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), 0);

        // check l1escrow got the L1_EURC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Eurc.balanceOf(address(_l1Escrow)), amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice converts 1000 L2_WEURC to L2_EURC, then calls migrate,
    /// Alice converts 500 L2_WEURC to L2_EURC, then calls migrate again,
    /// and the migrations execute correctly.
    function testMultipleMigratesWithWEURC() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // Alice converts some wEURC to EURC
        // this causes L2_WEURC to be sent to NativeConverter
        uint256 amount1 = _toEURC(1000);
        uint256 balance1 = _erc20L2wEURC.balanceOf(_alice);
        uint256 wEURCSupply1 = _erc20L2wEURC.totalSupply();
        _erc20L2wEURC.approve(address(_nativeConverter), amount1);
        _nativeConverter.convert(_alice, amount1, _emptyBytes);

        // check that NativeConverter has the L2_BWEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount1);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent();

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Migrate(amount1);

        // migrate all of the L2_BWEURC to L1
        vm.startPrank(_owner);
        _nativeConverter.migrate();
        vm.stopPrank();

        vm.startPrank(_alice);

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2Fork, _l1Fork);

        // check alice no longer has the L2_WEURC
        vm.selectFork(_l2Fork);
        uint256 balance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(balance1 - balance2, amount1);

        // check nativeconverter no longer has L2_WEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), 0);

        // check l1escrow got the L1_EURC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Eurc.balanceOf(address(_l1Escrow)), amount1);

        // _assertEurcSupplyAndBalancesMatch();

        // Alice converts some more wEURC to EURC
        vm.selectFork(_l2Fork);
        uint256 amount2 = _toEURC(500);
        _erc20L2wEURC.approve(address(_nativeConverter), amount2);
        _nativeConverter.convert(_alice, amount2, _emptyBytes);

        // check that NativeConverter has the L2_BWEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount2);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent();

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Migrate(amount2);

        // migrate all of the L2_BWEURC to L1
        vm.startPrank(_owner);
        _nativeConverter.migrate();
        vm.stopPrank();

        vm.startPrank(_alice);

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2Fork, _l1Fork);

        // check alice no longer has the L2_WEURC
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(balance2 - balance3, amount2);

        // check nativeconverter no longer has L2_WEURC
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), 0);

        // check that the supply of L2_WEURC decreased
        // uint256 wEURCSupply2 = _erc20L2wEURC.totalSupply();
        // assertEq(wEURCSupply1 - wEURCSupply2, amount1 + amount2);

        // check l1escrow got the L1_EURC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Eurc.balanceOf(address(_l1Escrow)), amount1 + amount2);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// No L2_WEURC is present in the bridge, and migrate is called.
    function testMigrateWithoutWEURC() public {
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Eurc.balanceOf(address(_l1Escrow)), 0);

        vm.selectFork(_l2Fork);
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), 0);

        // nothing happens
        vm.startPrank(_owner);
        _nativeConverter.migrate();
        vm.stopPrank();

        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), 0);

        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Eurc.balanceOf(address(_l1Escrow)), 0);

        // _assertEurcSupplyAndBalancesMatch();
    }
}
