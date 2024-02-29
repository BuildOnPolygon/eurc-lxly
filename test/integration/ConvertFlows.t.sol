// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base, Events} from "../Base.sol";

contract ConvertFlows is Base {
    bytes private _emptyBytes;

    /// @notice Alice converts 1000 L2_WEURC to L2_EURC for herself, using approve().
    function testConvertsWrappedEurcToNativeEurc() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_alice);

        uint256 amount = _toEURC(1000);
        _erc20L2wEURC.approve(address(_nativeConverter), amount);

        // check that our convert event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Convert(_alice, _alice, amount);

        // call convert
        _nativeConverter.convert(_alice, amount, _emptyBytes);

        // alice's L2_WEURC balance decreased
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(wrappedBalance1 - wrappedBalance2, amount);

        // alice's L2_EURC balance increased
        assertEq(_erc20L2Eurc.balanceOf(_alice), amount);

        // converter's L2_BWEURC balance increased
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice converts 1000 L2_WEURC to L2_EURC for herself, using permit().
    function testConvertsWithPermit() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_alice);

        uint256 amount = _toEURC(1000);
        bytes memory permitData = _createPermitData(_alice, address(_nativeConverter), _l2wEURC, amount);

        // check that our convert event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Convert(_alice, _alice, amount);

        // call convert
        _nativeConverter.convert(_alice, amount, permitData);

        // alice's L2_WEURC balance decreased
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(wrappedBalance1 - wrappedBalance2, amount);

        // alice's L2_EURC balance increased
        assertEq(_erc20L2Eurc.balanceOf(_alice), amount);

        // converter's L2_BWEURC balance increased
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice permits a 500 L2_WEURC spend but tries to convert 1000 L2_WEURC.
    function testRevertConvertWithInsufficientPermit() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_alice);

        uint256 approveAmount = _toEURC(500);
        uint256 convertAmount = _toEURC(1000);
        bytes memory permitData = _createPermitData(_alice, address(_nativeConverter), _l2wEURC, approveAmount);

        // call convert
        vm.expectRevert(bytes4(0x03fffc4b)); // NotValidAmount()
        _nativeConverter.convert(_alice, convertAmount, permitData);

        // alice's L2_WEURC balance didn't change
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(wrappedBalance1, wrappedBalance2);

        // alice's L2_EURC balance didn't change
        assertEq(_erc20L2Eurc.balanceOf(_alice), 0);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice converts 1000 L2_WEURC to L2_EURC for Bob.
    function testConvertsWrappedEurcToNativeEurcForAnotherAddress() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_alice);

        uint256 amount = _toEURC(1000);
        _erc20L2wEURC.approve(address(_nativeConverter), amount);

        // check that our convert event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Convert(_alice, _bob, amount);

        // call convert
        _nativeConverter.convert(_bob, amount, _emptyBytes);

        // alice's L2_WEURC balance decreased
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(wrappedBalance1 - wrappedBalance2, amount);

        // bob's L2_EURC balance increased
        assertEq(_erc20L2Eurc.balanceOf(_bob), amount);

        // converter's L2_BWEURC balance increased
        assertEq(_erc20L2wEURC.balanceOf(address(_nativeConverter)), amount);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice approves a 500 L2_WEURC spend but tries to convert 1000 L2_WEURC.
    function testRevertConvertWithInsufficientApproval() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_alice);

        uint256 approveAmount = _toEURC(500);
        uint256 convertAmount = _toEURC(1000);
        _erc20L2wEURC.approve(address(_nativeConverter), approveAmount);

        // call convert
        vm.expectRevert("ERC20: insufficient allowance");
        _nativeConverter.convert(_alice, convertAmount, _emptyBytes);

        // alice's L2_WEURC balance didn't change
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_alice);
        assertEq(wrappedBalance1, wrappedBalance2);

        // alice's L2_EURC balance didn't change
        assertEq(_erc20L2Eurc.balanceOf(_alice), 0);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to convert 0 L2_WEURC.
    function testRevertConvertingZero() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // try to convert 0 L2_WEURC to L2_EURC
        _erc20L2wEURC.approve(address(_nativeConverter), 0);
        vm.expectRevert("INVALID_AMOUNT");
        _nativeConverter.convert(_alice, 0, _emptyBytes);

        // _assertEurcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to convert 1000 L2_WEURC for address zero.
    function testRevertConvertingForAddressZero() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // try to convert 1000 L2_WEURC for address 0
        _erc20L2wEURC.approve(address(_nativeConverter), _toEURC(1000));
        vm.expectRevert("INVALID_RECEIVER");
        _nativeConverter.convert(address(0), _toEURC(1000), _emptyBytes);

        // _assertEurcSupplyAndBalancesMatch();
    }

    function testConverNativeEurcToWrappedEurc() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // setup: alice converts wrapped to native ("seeding" the nativeconverter) and sends to bob
        uint256 amount = _toEURC(10000);
        _erc20L2wEURC.approve(address(_nativeConverter), amount);
        _nativeConverter.convert(_bob, amount, _emptyBytes);
        vm.stopPrank();

        // deconvert
        vm.startPrank(_bob);

        // frank has no wrapped
        uint256 wrappedBalance1 = _erc20L2wEURC.balanceOf(_frank);
        assertEq(wrappedBalance1, 0);

        // bob converts 8k native to wrapped, with frank as the receiver
        uint256 amount2 = _toEURC(8000);
        _erc20L2Eurc.approve(address(_nativeConverter), amount2);

        // check that our convert event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Events.Deconvert(_bob, _frank, amount2);

        _nativeConverter.deconvert(_frank, amount2, _emptyBytes);

        // frank has 8k wrapped
        uint256 wrappedBalance2 = _erc20L2wEURC.balanceOf(_frank);
        assertEq(wrappedBalance2, amount2);

        // _assertEurcSupplyAndBalancesMatch();
    }
}
