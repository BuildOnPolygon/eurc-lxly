// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IEURC} from "./interfaces/IEURC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

/// @title NativeConverter
/// @notice This contract will receive BridgeWrappedEURC on zkEVM and issue EURC.e on the zkEVM.
/// @notice This contract will hold the minter role giving it the ability to mint EURC based on
/// inflows of BridgeWrappedEURC. This contract will also have a permissionless publicly
/// callable function called “migrate” which when called will burn all BridgedWrappedEURC
/// on the L2, and send a message to the bridge that causes all of the corresponding
/// backing L1 EURC to be sent to the L1Escrow. This aligns the balance of the L1Escrow
/// contract with the total supply of EURC on the zkEVM.
contract NativeConverter is CommonAdminOwner {
    using SafeERC20Upgradeable for IEURC;

    event Convert(address indexed from, address indexed to, uint256 amount);
    event Deconvert(address indexed from, address indexed to, uint256 amount);
    event Migrate(uint256 amount);

    /// @notice the PolygonZkEVMBridge deployed on the zkEVM
    IPolygonZkEVMBridge public bridge;

    /// @notice The ID used internally by the bridge to identify L1 messages. Initially
    /// set to be `0`
    uint32 public l1NetworkId;

    /// @notice The address of the L1Escrow
    address public l1Escrow;

    /// @notice The L2 EURC deployed on the zkEVM
    IEURC public zkEURCe;

    /// @notice The default L2 EURC TokenWrapped token deployed on the zkEVM
    IEURC public zkBWEURC;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    /// @notice Setup the state variables of the upgradeable NativeConverter contract
    /// @notice The owner is the address that is able to pause and unpause function calls
    /// @param owner_ the address that will be able to pause and unpause the contract,
    /// as well as transfer the ownership of the contract
    /// @param bridge_ the address of the PolygonZkEVMBridge deployed on the zkEVM
    /// @param l1NetworkId_ the ID used internally by the bridge to identify L1 messages
    /// @param l1EscrowProxy_ the address of the L1Escrow deployed on the L1
    /// @param zkEURCe_ the address of the L2 EURC deployed on the zkEVM
    /// @param zkBWEURC_ the address of the default L2 EURC TokenWrapped token deployed on the zkEVM
    function initialize(
        address owner_,
        address admin_,
        address bridge_,
        uint32 l1NetworkId_,
        address l1EscrowProxy_,
        address zkEURCe_,
        address zkBWEURC_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(l1EscrowProxy_ != address(0), "INVALID_L1ESCROW");
        require(zkEURCe_ != address(0), "INVALID_EURC_E");
        require(zkBWEURC_ != address(0), "INVALID_BW_UDSC");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
        l1Escrow = l1EscrowProxy_;
        zkEURCe = IEURC(zkEURCe_);
        zkBWEURC = IEURC(zkBWEURC_);
    }

    /// @notice Converts L2 BridgeWrappedEURC to L2 EURC
    /// @dev The NativeConverter transfers L2 BridgeWrappedEURC from the caller to itself and
    /// mints L2 EURC to the caller
    /// @param receiver address that will receive L2 EURC on the L2
    /// @param amount amount of L2 BridgeWrappedEURC to convert
    /// @param permitData data for the permit call on the L2 BridgeWrappedEURC
    function convert(address receiver, uint256 amount, bytes calldata permitData) external whenNotPaused {
        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        if (permitData.length > 0) {
            LibPermit.permit(address(zkBWEURC), amount, permitData);
        }

        // transfer the wrapped eurc to the converter, and mint back native eurc
        zkBWEURC.safeTransferFrom(msg.sender, address(this), amount);
        zkEURCe.mint(receiver, amount);

        emit Convert(msg.sender, receiver, amount);
    }

    function deconvert(address receiver, uint256 amount, bytes calldata permitData) external whenNotPaused {
        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");
        require(amount <= zkBWEURC.balanceOf(address(this)), "AMOUNT_TOO_LARGE");

        if (permitData.length > 0) {
            LibPermit.permit(address(zkEURCe), amount, permitData);
        }

        // transfer native eurc from user to the converter, and burn it
        zkEURCe.safeTransferFrom(msg.sender, address(this), amount);
        zkEURCe.burn(amount);

        // and then send bridge wrapped eurc to the user
        zkBWEURC.safeTransfer(receiver, amount);

        emit Deconvert(msg.sender, receiver, amount);
    }

    /// @notice Migrates L2 BridgeWrappedEURC EURC to L1 EURC
    /// @dev Any BridgeWrappedEURC transfered in by previous calls to
    /// `convert` will be burned and the corresponding
    /// L1 EURC will be sent to the L1Escrow via a message to the bridge
    function migrate() external onlyOwner whenNotPaused {
        // Anyone can call migrate() on NativeConverter to
        // have all zkBridgeWrappedEURC withdrawn via the PolygonZkEVMBridge
        // moving the L1_EURC held in the PolygonZkEVMBridge to L1Escrow

        uint256 amount = zkBWEURC.balanceOf(address(this));

        if (amount > 0) {
            zkBWEURC.approve(address(bridge), amount);

            bridge.bridgeAsset(
                l1NetworkId,
                l1Escrow,
                amount,
                address(zkBWEURC),
                true, // forceUpdateGlobalExitRoot
                "" // empty permitData because we're doing approve
            );

            emit Migrate(amount);
        }
    }
}
