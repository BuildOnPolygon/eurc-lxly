// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base, Events} from "../Base.sol";

contract WithdrawUnlockFlows is Base {
    function _depositToL1Escrow() internal {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);
        uint256 amount = _toEURC(1000);
        _erc20L1Eurc.approve(address(_l1Escrow), amount);
        _l1Escrow.bridgeToken(_alice, amount, false);
        _claimBridgeMessage(_l1Fork, _l2Fork);
    }

    function setUp() public override {
        Base.setUp();
        _depositToL1Escrow();
    }

    /// @notice Alice has 1000 L2_EURC, withdraws it all using approve(), and gets back 1000 L1_EURC
    function testFullWithdrawBurnsAndUnlocksInL1() public {
        // get the initial L1 balance
        vm.selectFork(_l1Fork);
        uint256 l1Balance1 = _erc20L1Eurc.balanceOf(_alice);

        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(1000);
        _erc20L2Eurc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitWithdrawBridgeEvent(_alice, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Events.Withdraw(_alice, _alice, amount);

        // burn the L2_EURC
        _minterBurner.bridgeToken(_alice, amount, true);

        // alice's L2_EURC balance is 0
        uint256 l2Balance = _erc20L2Eurc.balanceOf(_alice);
        assertEq(l2Balance, 0);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // alice's L1_EURC balance increased
        vm.selectFork(_l1Fork);
        uint256 l1Balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(l1Balance2 - l1Balance1, amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_EURC, withdraws it all using permit(), and gets back 1000 L1_EURC
    function testFullWithdrawBurnsWithPermitAndUnlocksInL1() public {
        // get the initial L1 balance
        vm.selectFork(_l1Fork);
        uint256 l1Balance1 = _erc20L1Eurc.balanceOf(_alice);

        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(1000);
        bytes memory permitData = _createPermitData(_alice, address(_minterBurner), _l2Eurc, amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitWithdrawBridgeEvent(_alice, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Events.Withdraw(_alice, _alice, amount);

        // burn the L2_EURC
        _minterBurner.bridgeToken(_alice, amount, true, permitData);

        // alice's L2_EURC balance is 0
        uint256 l2Balance = _erc20L2Eurc.balanceOf(_alice);
        assertEq(l2Balance, 0);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // alice's L1_EURC balance increased
        vm.selectFork(_l1Fork);
        uint256 l1Balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(l1Balance2 - l1Balance1, amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice permits spending 500 L2_EURC and tries to withdraw 1000 L2_EURC.
    function testRevertWithdrawWithInsufficientPermit() public {
        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 balance1 = _erc20L2Eurc.balanceOf(_alice);

        uint256 approvalAmount = _toEURC(500);
        uint256 withdrawAmount = _toEURC(1000);
        bytes memory permitData = _createPermitData(_alice, address(_minterBurner), _l2Eurc, approvalAmount);

        // try to withdraw the L2_EURC
        vm.expectRevert(bytes4(0x03fffc4b)); // NotValidAmount()
        _minterBurner.bridgeToken(_alice, withdrawAmount, true, permitData);

        // alice's L2_EURC balance is the same
        uint256 balance2 = _erc20L2Eurc.balanceOf(_alice);
        assertEq(balance1, balance2);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_EURC, withdraws 75%, and gets back 750 L1_EURC
    function testPartialWithdrawBurnsAndUnlocksInL1() public {
        // get the initial L1 balance
        vm.selectFork(_l1Fork);
        uint256 l1Balance1 = _erc20L1Eurc.balanceOf(_alice);

        // setup the withdrawal for 750 L2_EURC
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(750);
        _erc20L2Eurc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitWithdrawBridgeEvent(_alice, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Events.Withdraw(_alice, _alice, amount);

        // burn the L2_EURC
        _minterBurner.bridgeToken(_alice, amount, true);

        // alice's L2_EURC balance is 1000 - 750 = 250
        uint256 l2Balance = _erc20L2Eurc.balanceOf(_alice);
        assertEq(l2Balance, _toEURC(250));

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // alice's L1_EURC balance increased
        vm.selectFork(_l1Fork);
        uint256 l1Balance2 = _erc20L1Eurc.balanceOf(_alice);
        assertEq(l1Balance2 - l1Balance1, amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_EURC, withdraws it all to Bob, who receives 1000 L1_EURC
    function testWithdrawsToAnotherAddress() public {
        // get alice's original L1 balance
        vm.selectFork(_l1Fork);
        uint256 aliceL1Balance = _erc20L1Eurc.balanceOf(_alice);

        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(1000);
        _erc20L2Eurc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitWithdrawBridgeEvent(_bob, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Events.Withdraw(_alice, _bob, amount);

        // withdraw the L2_EURC to bob
        _minterBurner.bridgeToken(_bob, amount, true);

        // alice's L2_EURC balance is 0
        uint256 l2Balance = _erc20L2Eurc.balanceOf(_alice);
        assertEq(l2Balance, 0);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // bob's L1_EURC balance increased
        vm.selectFork(_l1Fork);
        uint256 bobL1Balance = _erc20L1Eurc.balanceOf(_bob);
        assertEq(bobL1Balance, amount);

        // alice's L1_EURC balance is the same
        assertEq(_erc20L1Eurc.balanceOf(_alice), aliceL1Balance);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_EURC and tries to withdraw to address 0.
    function testRevertWhenWithdrawingToAddressZero() public {
        // setup
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(1000);
        _erc20L2Eurc.approve(address(_minterBurner), amount);

        // reverts when trying to withdraw the L2_EURC
        vm.expectRevert("INVALID_RECEIVER");
        _minterBurner.bridgeToken(address(0), amount, true);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_EURC and tries to withdraw 2000 L2_EURC.
    function testRevertWhenWithdrawingMoreThanBalance() public {
        // setup the withdrawal for 2000 L2_EURC
        vm.selectFork(_l2Fork);
        uint256 amount = _toEURC(2000);
        _erc20L2Eurc.approve(address(_minterBurner), amount);

        // reverts when trying to withdraw the L2_EURC
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        _minterBurner.bridgeToken(_alice, amount, true);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to withdraw 0 L2_EURC.
    function testRevertWhenWithdrawingZero() public {
        // setup the withdrawal for 0 L2_EURC
        vm.selectFork(_l2Fork);
        _erc20L2Eurc.approve(address(_minterBurner), 0);

        // reverts when trying to withdraw zero
        vm.expectRevert("FiatToken: burn amount not greater than 0");
        _minterBurner.bridgeToken(_alice, 0, true);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice approves spending 500 L2_EURC and tries to withdraw 1000 L2_EURC.
    function testRevertWithdrawWithInsufficientApproval() public {
        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 balance1 = _erc20L2Eurc.balanceOf(_alice);

        uint256 approvalAmount = _toEURC(500);
        uint256 withdrawAmount = _toEURC(1000);
        _erc20L2Eurc.approve(address(_minterBurner), approvalAmount);

        // try to withdraw the L2_EURC
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        _minterBurner.bridgeToken(_alice, withdrawAmount, true);

        // alice's L2_EURC balance is the same
        uint256 balance2 = _erc20L2Eurc.balanceOf(_alice);
        assertEq(balance1, balance2);

        // _assertEurcSupplyAndBalancesMatch();
    }
}
