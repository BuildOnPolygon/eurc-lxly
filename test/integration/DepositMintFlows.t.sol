// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base, Events} from "../Base.sol";

contract DepositMintFlows is Base {
    /// @notice Alice deposits 1000 L1_EURC to L1Escrow using approve(), and MinterBurner mints back 1000 L2_EURC
    function testDepositToL1EscrowMintsInL2() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toEURC(1000);
        uint256 balance1 = _erc20L1Eurc.balanceOf(_alice);
        _erc20L1Eurc.approve(address(_l1Escrow), amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitDepositBridgeEvent(_alice, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Events.Deposit(_alice, _alice, amount);

        // deposit to L1Escrow
        _l1Escrow.bridgeToken(_alice, amount, false);

        // alice's L1_EURC balance decreased
        uint256 balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_EURC balance increased
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Eurc.balanceOf(_alice);
        assertEq(balance3, amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice deposits 1000 L1_EURC to L1Escrow using permit(), and MinterBurner mints back 1000 L2_EURC
    function testDepositsWithPermit() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toEURC(1000);
        uint256 balance1 = _erc20L1Eurc.balanceOf(_alice);
        bytes memory permitData = _createPermitData(_alice, address(_l1Escrow), _l1Eurc, amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitDepositBridgeEvent(_alice, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Events.Deposit(_alice, _alice, amount);

        // deposit to L1Escrow
        _l1Escrow.bridgeToken(_alice, amount, false, permitData);

        // alice's L1_EURC balance decreased
        uint256 balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_EURC balance increased
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Eurc.balanceOf(_alice);
        assertEq(balance3, amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice permits a 500 L1_EURC spend but tries to deposit 1000 L1_EURC to L1Escrow.
    function testRevertDepositWithInsufficientPermit() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 approvalAmount = _toEURC(500);
        uint256 depositAmount = _toEURC(1000);

        uint256 balance1 = _erc20L1Eurc.balanceOf(_alice);
        bytes memory permitData = _createPermitData(_alice, address(_l1Escrow), _l1Eurc, approvalAmount);

        // deposit to L1Escrow
        vm.expectRevert(bytes4(0x03fffc4b)); // NotValidAmount()
        _l1Escrow.bridgeToken(_alice, depositAmount, true, permitData);

        // alice's L1_EURC balance is the same
        uint256 balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(balance1, balance2);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice deposits 1000 L1_EURC to L1Escrow for Bob, and MinterBurner mints the L2_EURC accordingly.
    function testDepositToAnotherAddress() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toEURC(1000);
        uint256 balance1 = _erc20L1Eurc.balanceOf(_alice);
        _erc20L1Eurc.approve(address(_l1Escrow), amount);

        // check that a bridge event is emitted
        vm.expectEmit(false, false, false, false, _bridge);
        _emitDepositBridgeEvent(_bob, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Events.Deposit(_alice, _bob, amount);

        // deposit to L1Escrow for bob
        _l1Escrow.bridgeToken(_bob, amount, false);

        // alice's L1_EURC balance decreased
        uint256 balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_EURC balance didn't change
        vm.selectFork(_l2Fork);
        assertEq(_erc20L2Eurc.balanceOf(_alice), 0);

        // but bob's L2_EURC balance increased
        assertEq(_erc20L2Eurc.balanceOf(_bob), amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to deposit 0 L1_EURC to L1Escrow.
    function testRevertDepositingZero() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // try to deposit 0 to L1Escrow
        _erc20L1Eurc.approve(address(_l1Escrow), 0);
        vm.expectRevert("INVALID_AMOUNT");
        _l1Escrow.bridgeToken(_alice, 0, true);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to deposit 1000 L1_EURC to L1Escrow for address zero.
    function testRevertDepositingToAddressZero() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // try to deposit 1000 to L1Escrow for address 0
        _erc20L1Eurc.approve(address(_l1Escrow), _toEURC(1000));
        vm.expectRevert("INVALID_RECEIVER");
        _l1Escrow.bridgeToken(address(0), _toEURC(1000), true);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice approves a 500 L1_EURC spend but tries to deposit 1000 L1_EURC to L1Escrow.
    function testRevertDepositWithInsufficientApproval() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 approvalAmount = _toEURC(500);
        uint256 depositAmount = _toEURC(1000);

        uint256 balance1 = _erc20L1Eurc.balanceOf(_alice);
        _erc20L1Eurc.approve(address(_l1Escrow), approvalAmount);

        // deposit to L1Escrow
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        _l1Escrow.bridgeToken(_alice, depositAmount, true);

        // alice's L1_EURC balance is the same
        uint256 balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(balance1, balance2);

        // _assertEurcSupplyAndBalancesMatch();
    }
}
