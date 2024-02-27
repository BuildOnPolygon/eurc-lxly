// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IEURC} from "./interfaces/IEURC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

/// @title L1Escrow
/// @notice This upgradeable contract receives EURC from users on L1 and uses the PolygonZkEVMBridge
/// to send a message to the MinterBurner contract on the L2 (zkEVM) which
/// then mints EURC for users
/// @notice This contract is upgradeable using UUPS, and can have its important functions
/// paused and unpaused
contract L1Escrow is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IEURC;

    event Deposit(address indexed from, address indexed to, uint256 amount);

    /// @notice The singleton bridge contract on both L1 and L2 (zkEVM) that faciliates
    /// bridging messages between L1 and L2. It also stores all of the L1 EURC
    /// backing the L2 BridgeWrappedEURC
    IPolygonZkEVMBridge public bridge;

    /// @notice The ID used internally by the bridge to identify zkEVM messages. Initially
    /// set to be `1`
    uint32 public zkNetworkId;

    /// @notice Address of the L2 MinterBurner, which receives messages from the L1Escrow
    address public MinterBurner;

    /// @notice Address of the L1 EURC token
    IEURC public l1EURC;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    /// @notice Setup the state variables of the upgradeable L1Escrow contract
    /// @notice The owner is the address that is able to pause and unpause function calls
    /// @param owner_ the address that will be able to pause and unpause the contract,
    /// as well as transfer the ownership of the contract
    /// @param bridge_ the address of the PolygonZkEVMBridge deployed on the zkEVM
    /// @param zkNetworkId_ the ID used internally by the bridge to identify zkEVM messages
    /// @param MinterBurnerProxy_ the address of the MinterBurnerProxy deployed on the L2
    /// @param l1EURC_ the address of the L1 EURC deployed on the L1
    function initialize(
        address owner_,
        address admin_,
        address bridge_,
        uint32 zkNetworkId_,
        address MinterBurnerProxy_,
        address l1EURC_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(MinterBurnerProxy_ != address(0), "INVALID_MB");
        require(l1EURC_ != address(0), "INVALID_L1_EURC");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        zkNetworkId = zkNetworkId_;
        MinterBurner = MinterBurnerProxy_;
        l1EURC = IEURC(l1EURC_);
    }

    /// @notice Bridges L1 EURC to L2 EURC
    /// @dev The L1Escrow transfers L1 EURC from the caller to itself and
    /// calls `bridge.bridgeMessage, which ultimately results in a message
    /// received on the L2 MinterBurner which mints EURC for the destination
    /// address
    /// @dev Can be paused
    /// @param destinationAddress address that will receive EURC on the L2
    /// @param amount amount of L1 EURC to bridge
    /// @param forceUpdateGlobalExitRoot whether or not to force the bridge to update.
    function bridgeToken(address destinationAddress, uint256 amount, bool forceUpdateGlobalExitRoot)
        public
        whenNotPaused
    {
        // User calls `bridgeToken` on L1Escrow, L1_EURC is transferred to L1Escrow
        // message sent to PolygonZkEvmBridge targeted to L2's MinterBurner.

        require(destinationAddress != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // move L1-EURC from the user to the escrow
        l1EURC.safeTransferFrom(msg.sender, address(this), amount);
        // tell our MinterBurner to mint zkEURCe to the receiver
        bytes memory data = abi.encode(destinationAddress, amount);
        bridge.bridgeMessage(zkNetworkId, MinterBurner, forceUpdateGlobalExitRoot, data);

        emit Deposit(msg.sender, destinationAddress, amount);
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
            LibPermit.permit(address(l1EURC), amount, permitData);
        }

        bridgeToken(destinationAddress, amount, forceUpdateGlobalExitRoot);
    }

    /// @dev This function is triggered by the bridge to faciliate the L1 EURC withdrawal process.
    /// This function is called by the bridge when a message is sent by the L2
    /// MinterBurner communicating that it has burned EURC and wants to withdraw the L1 EURC
    /// that backs it.
    /// @dev This function can only be called by the bridge contract
    /// @dev Can be paused
    /// @param originAddress address that initiated the message on the L2
    /// @param originNetwork network that initiated the message on the L2
    /// @param data data that was sent with the message on the L2, includes the
    /// `l1Receiver` and `amount` of L1 EURC to send to the `l1Receiver`
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data)
        external
        payable
        whenNotPaused
    {
        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(MinterBurner == originAddress, "NOT_MINTER_BURNER");
        require(zkNetworkId == originNetwork, "NOT_ZK_CHAIN");

        // decode message data and call transfer
        (address l1Receiver, uint256 amount) = abi.decode(data, (address, uint256));

        // kinda redundant - these checks are being done by the caller
        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // send the locked L1_EURC to the receiver
        l1EURC.safeTransfer(l1Receiver, amount);
    }
}
