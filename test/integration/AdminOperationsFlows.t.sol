// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";
import "../../src/L1Escrow.sol";
import "../../src/NativeConverter.sol";
import "../../src/MinterBurner.sol";

contract AdminAndOwnerOperationsFlows is Base {
    event AdminChanged(address previousAdmin, address newAdmin);
    event Upgraded(address indexed implementation);

    /// @notice Admin can upgrade contracts to a valid address.

    function testAdminCanUpgradeL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_admin);

        L1Escrow newImpl = new L1Escrow();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_l1Escrow));
        emit Upgraded(newImplAddr);
        _l1Escrow.upgradeTo(newImplAddr);
    }

    function testAdminCanUpgradeMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_admin);

        MinterBurner newImpl = new MinterBurner();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_minterBurner));
        emit Upgraded(newImplAddr);
        _minterBurner.upgradeTo(newImplAddr);
    }

    function testAdminCanUpgradeNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_admin);

        NativeConverter newImpl = new NativeConverter();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_nativeConverter));
        emit Upgraded(newImplAddr);
        _nativeConverter.upgradeTo(newImplAddr);
    }

    /// @notice Non-Admin cannot upgrade contracts.

    function testRevertNonAdminCannotUpgradeL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        L1Escrow newImpl = new L1Escrow();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _l1Escrow.upgradeTo(newImplAddr);
    }

    function testRevertNonAdminCannotUpgradeMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        MinterBurner newImpl = new MinterBurner();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _minterBurner.upgradeTo(newImplAddr);
    }

    function testRevertNonAdminCannotUpgradeNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        NativeConverter newImpl = new NativeConverter();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _nativeConverter.upgradeTo(newImplAddr);
    }

    /// @notice Owner can pause and unpause contracts.

    function testOwnerCanPauseUnpauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_owner);

        assertEq(_l1Escrow.paused(), false);
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), true);
        _l1Escrow.unpause();
        assertEq(_l1Escrow.paused(), false);
    }

    function testOwnerCanPauseUnpauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_owner);

        assertEq(_minterBurner.paused(), false);
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), true);
        _minterBurner.unpause();
        assertEq(_minterBurner.paused(), false);
    }

    function testOwnerCanPauseUnpauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_owner);

        assertEq(_nativeConverter.paused(), false);
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), true);
        _nativeConverter.unpause();
        assertEq(_nativeConverter.paused(), false);
    }

    /// @notice Contracts are unpaused, a non-owner tries to pause them, but it reverts.

    function testRevertNonOwnerCannotPauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        assertEq(_l1Escrow.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), false);
    }

    function testRevertNonOwnerCannotPauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        assertEq(_minterBurner.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), false);
    }

    function testRevertNonOwnerCannotPauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        assertEq(_nativeConverter.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), false);
    }

    /// @notice Contracts are paused, a non-owner tries to unpause them, but it reverts.

    function testRevertNonOwnerCannotPauseUnpauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_owner);
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _l1Escrow.unpause();
        assertEq(_l1Escrow.paused(), true);
    }

    function testRevertNonOwnerCannotPauseUnpauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_owner);
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _minterBurner.unpause();
        assertEq(_minterBurner.paused(), true);
    }

    function testRevertNonOwnerCannotPauseUnpauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_owner);
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _nativeConverter.unpause();
        assertEq(_nativeConverter.paused(), true);
    }

    /// @notice Admin can change admin.

    function testAdminCanChangeAdminL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_admin);

        // set alice as admin
        vm.expectEmit(address(_l1Escrow));
        emit AdminChanged(_admin, _alice);
        _l1Escrow.changeAdmin(_alice);

        // check that deployer is no longer admin
        vm.expectRevert("NOT_ADMIN");
        _l1Escrow.changeAdmin(_alice);

        // check that alice is admin by transferring back admin to deployer
        vm.startPrank(_alice);
        vm.expectEmit(address(_l1Escrow));
        emit AdminChanged(_alice, _admin);
        _l1Escrow.changeAdmin(_admin);
    }

    function testAdminCanChangeAdminMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_admin);

        // set alice as admin
        vm.expectEmit(address(_minterBurner));
        emit AdminChanged(_admin, _alice);
        _minterBurner.changeAdmin(_alice);

        // check that deployer is no longer admin
        vm.expectRevert("NOT_ADMIN");
        _minterBurner.changeAdmin(_alice);

        // check that alice is admin by transferring back admin to deployer
        vm.startPrank(_alice);
        vm.expectEmit(address(_minterBurner));
        emit AdminChanged(_alice, _admin);
        _minterBurner.changeAdmin(_admin);
    }

    function testAdminCanChangeAdminNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_admin);

        // set alice as admin
        vm.expectEmit(address(_nativeConverter));
        emit AdminChanged(_admin, _alice);
        _nativeConverter.changeAdmin(_alice);

        // check that deployer is no longer admin
        vm.expectRevert("NOT_ADMIN");
        _nativeConverter.changeAdmin(_alice);

        // check that alice is admin by transferring back admin to deployer
        vm.startPrank(_alice);
        vm.expectEmit(address(_nativeConverter));
        emit AdminChanged(_alice, _admin);
        _nativeConverter.changeAdmin(_admin);
    }
}
