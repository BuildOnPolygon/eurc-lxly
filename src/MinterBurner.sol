// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IEURC} from "./interfaces/IEURC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

/// @title MinterBurner
/// @notice This upgradeable L2 contract facilitates 2 actions:
/// 1. Minting EURC on the zkEVM backed by L1 EURC held in the L1Escrow
/// 2. Burning EURC on the zkEVM and sending a bridge message to unlock the
/// corresponding funds held in the L1Escrow (the reverse of (1) above).
contract MinterBurner is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IEURC;

    event Withdraw(address indexed from, address indexed to, uint256 amount);

    /// @notice The singleton bridge contract on both L1 and L2 (zkEVM) that faciliates
    /// bridging messages between L1 and L2. It also stores all of the L1 EURC
    /// backing the L2 BridgeWrappedEURC
    IPolygonZkEVMBridge public bridge;

    /// @notice The ID used internally by the bridge to identify L1 messages. Initially
    /// set to be `0`
    uint32 public l1NetworkId;

    /// @notice The address of the L1Escrow
    address public l1Escrow;

    /// @notice The address of the L2 EURC ERC20 token
    IEURC public zkEURCe;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    /// @notice Setup the state variables of the upgradeable MinterBurner contract
    /// @notice The owner is the address that is able to pause and unpause function calls
    /// @param owner_ the address that will be able to pause and unpause the contract,
    /// as well as transfer the ownership of the contract
    /// @param bridge_ the address of the PolygonZkEVMBridge deployed on the zkEVM
    /// @param l1NetworkId_ the ID used internally by the bridge to identify L1 messages
    /// @param l1EscrowProxy_ the address of the L1EscrowProxy deployed on the L1
    /// @param zkEURCe_ the address of the L2 EURC deployed on the zkEVM
    function initialize(
        address owner_,
        address admin_,
        address bridge_,
        uint32 l1NetworkId_,
        address l1EscrowProxy_,
        address zkEURCe_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(l1EscrowProxy_ != address(0), "INVALID_L1ESCROW");
        require(zkEURCe_ != address(0), "INVALID_EURC_E");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
        l1Escrow = l1EscrowProxy_;
        zkEURCe = IEURC(zkEURCe_);
    }

    /// @notice Bridges L2 EURC to L1 EURC
    /// @dev The MinterBurner transfers L2 EURC from the caller to itself and
    /// burns it, then calls `bridge.bridgeMessage`, which ultimately results in a message
    /// received on the L1Escrow which unlocks the corresponding L1 EURC to the
    /// destination address
    /// @dev Can be paused
    /// @param destinationAddress address that will receive L1 EURC on the L1
    /// @param amount amount of L2 EURC to bridge
    /// @param forceUpdateGlobalExitRoot whether or not to force the bridge to update
    function bridgeToken(address destinationAddress, uint256 amount, bool forceUpdateGlobalExitRoot)
        public
        whenNotPaused
    {
        require(destinationAddress != address(0), "INVALID_RECEIVER");
        // this is redundant - the EURC contract does the same validation
        // require(amount > 0, "INVALID_AMOUNT");

        // transfer the EURC from the user, and then burn it
        zkEURCe.safeTransferFrom(msg.sender, address(this), amount);
        zkEURCe.burn(amount);

        // message L1Escrow to unlock the L1_EURC and transfer it to destinationAddress
        bytes memory data = abi.encode(destinationAddress, amount);
        bridge.bridgeMessage(l1NetworkId, l1Escrow, forceUpdateGlobalExitRoot, data);

        emit Withdraw(msg.sender, destinationAddress, amount);
    }

    /// @notice Similar to other `bridgeToken` function, but saves an ERC20.approve call
    /// by using the EIP-2612 permit function
    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused {
        if (permitData.length > 0) {
            LibPermit.permit(address(zkEURCe), amount, permitData);
        }

        bridgeToken(destinationAddress, amount, forceUpdateGlobalExitRoot);
    }

    /// @dev This function is triggered by the bridge to faciliate the EURC minting process.
    /// This function is called by the bridge when a message is sent by the L1Escrow
    /// communicating that it has received L1 EURC and wants the MinterBurner to
    /// mint EURC.
    /// @dev This function can only be called by the bridge contract
    /// @dev Can be paused
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data)
        external
        payable
        whenNotPaused
    {
        // Function triggered by the bridge once a message is received from the L1Escrow

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(l1Escrow == originAddress, "NOT_L1_ESCROW_CONTRACT");
        require(l1NetworkId == originNetwork, "NOT_L1_CHAIN");

        // decode message data and call mint
        (address zkReceiver, uint256 amount) = abi.decode(data, (address, uint256));

        // this is redundant - the zkEURCe contract does the same validations
        // require(zkReceiver != address(0), "INVALID_RECEIVER");
        // require(amount > 0, "INVALID_AMOUNT");

        // mint zkEURCe to the receiver address
        zkEURCe.mint(zkReceiver, amount);
    }
}
