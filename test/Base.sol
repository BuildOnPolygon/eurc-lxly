// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LibDeployInit} from "../script/DeployInitHelpers.sol";
import "../src/interfaces/IEURC.sol";
import "../src/mocks/MockBridge.sol";
import "../src/L1EscrowProxy.sol";
import "../src/L1Escrow.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverter.sol";
import "../src/MinterBurnerProxy.sol";
import "../src/MinterBurner.sol";

library Events {
    /* ================= EVENTS ================= */
    // copy of PolygonZKEVMBridge.BridgeEvent
    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );

    // copy of NativeConverter.Convert
    event Convert(address indexed from, address indexed to, uint256 amount);

    // copy of NativeConverter.Deconvert
    event Deconvert(address indexed from, address indexed to, uint256 amount);

    // copy of L1Escrow.Deposit
    event Deposit(address indexed from, address indexed to, uint256 amount);

    // copy of NativeConverter.Migrate
    event Migrate(uint256 amount);

    // copy of MinterBurner.Withdraw
    event Withdraw(address indexed from, address indexed to, uint256 amount);
}

contract Base is Test {
    uint256 internal constant _ONE_MILLION_EURC = 10 ** 6 * 10 ** 6;

    /* ================= FIELDS ================= */
    uint256 internal _l1Fork;
    uint256 internal _l2Fork;
    uint32 internal _l1NetworkId;
    uint32 internal _l2NetworkId;

    // addresses
    address[] internal _actors;
    address internal _alice;
    address internal _bob;
    address internal _carol;
    address internal _dan;
    address internal _erin;
    address internal _frank;

    address internal _deployer;
    address internal _owner;
    address internal _admin;
    address internal _bridge;
    address internal _l1Eurc;
    address internal _l2Eurc;
    address internal _l2wEURC;

    // helper variables
    IERC20 internal _erc20L1Eurc;
    IERC20 internal _erc20L2Eurc;
    IERC20 internal _erc20L2wEURC;

    // L1 contracts
    L1Escrow internal _l1Escrow;

    // L2 contracts
    MinterBurner internal _minterBurner;
    NativeConverter internal _nativeConverter;

    /* ================= SETUP ================= */
    function setUp() public virtual {
        // create the forks
        _l1Fork = vm.createFork(vm.envString("L1_RPC_URL"));
        _l2Fork = vm.createFork(vm.envString("L2_RPC_URL"));
        _l1NetworkId = uint32(vm.envUint("L1_NETWORK_ID"));
        _l2NetworkId = uint32(vm.envUint("L2_NETWORK_ID"));

        // retrieve the addresses
        _bridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
        _l1Eurc = vm.envAddress("ADDRESS_L1_EURC");
        _l2Eurc = vm.envAddress("ADDRESS_L2_EURC");
        _l2wEURC = vm.envAddress("ADDRESS_L2_WEURC");
        _erc20L1Eurc = IERC20(_l1Eurc);
        _erc20L2Eurc = IERC20(_l2Eurc);
        _erc20L2wEURC = IERC20(_l2wEURC);

        _deployer = vm.addr(9);
        _owner = vm.addr(8);
        _admin = vm.addr(7);
        _alice = vm.addr(1);
        _bob = vm.addr(2);
        _carol = vm.addr(3);
        _dan = vm.addr(4);
        _erin = vm.addr(5);
        _frank = vm.addr(6);
        _actors = [_alice, _bob, _carol, _dan, _erin, _frank];

        // deploy and initialize contracts
        _deployMockBridge();
        _deployInitContracts();

        // fund alice with L1_EURC and L2_WEURC
        vm.selectFork(_l1Fork);
        _fundEURC(IEURC(_l1Eurc), _alice, _ONE_MILLION_EURC);
        _fundEURC(IEURC(_l1Eurc), _bridge, _ONE_MILLION_EURC);

        vm.selectFork(_l2Fork);
        deal(_l2wEURC, _alice, _ONE_MILLION_EURC);

        IEURC eurc = IEURC(_l2Eurc);
        vm.startPrank(eurc.masterMinter());
        eurc.configureMinter(address(_minterBurner), type(uint256).max);
        eurc.configureMinter(address(_nativeConverter), type(uint256).max);
        vm.stopPrank();
    }

    /* ================= HELPERS ================= */
    function _assertEurcSupplyAndBalancesMatch() internal {
        vm.selectFork(_l1Fork);
        uint256 l1EscrowBalance = _erc20L1Eurc.balanceOf(address(_l1Escrow));

        vm.selectFork(_l2Fork);
        uint256 l2TotalSupply = _erc20L2Eurc.totalSupply();
        uint256 wEurcConverterBalance = _erc20L2wEURC.balanceOf(address(_nativeConverter));

        // zkEurc.totalSupply <= l1Eurc.balanceOf(l1Escrow) + bwEURC.balanceOf(nativeConverter)
        assertLe(l2TotalSupply, l1EscrowBalance + wEurcConverterBalance);
    }

    function _claimBridgeMessage(uint256 from, uint256 to) internal {
        MockBridge b = MockBridge(_bridge);

        vm.selectFork(from);
        (
            uint32 originNetwork,
            address originAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            bytes memory metadata
        ) = b.lastBridgeMessage();
        // proof can be empty because our MockBridge bypasses the merkle tree verification
        // i.e. _verifyLeaf is always successful
        bytes32[32] memory proof;

        vm.selectFork(to);
        b.claimMessage(
            proof,
            uint32(b.depositCount()),
            "",
            "",
            originNetwork,
            originAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    function _claimBridgeAsset(uint256 from, uint256 to) internal {
        MockBridge b = MockBridge(_bridge);

        vm.selectFork(from);
        (
            uint32 originNetwork,
            address originTokenAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            bytes memory metadata
        ) = b.lastBridgeMessage();
        // proof and index can be empty because our MockBridge bypasses the merkle tree verification
        // i.e. _verifyLeaf is always successful
        bytes32[32] memory proof;
        uint32 index;

        vm.selectFork(to);
        b.claimAsset(
            proof,
            index,
            "",
            "",
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    function _createPermitData(address owner, address spender, address token, uint256 amount)
        internal
        view
        returns (bytes memory)
    {
        uint256 deadline = block.timestamp + 3600;

        // bytes32 domainSeparator = keccak256(
        //     abi.encode(
        //         keccak256(
        //             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        //         ),
        //         keccak256(bytes("USD Coin")),
        //         keccak256(bytes("2")), // NOTE: L1_EURC (and L2_EURC) uses 2 for version, while L2_WEURC uses 1 for version
        //         block.chainid,
        //         token
        //     )
        // );

        // using hardcoded hashes for the tests because of the different behaviour between the tokens
        bytes32 domainSeparator = IEURC(token).DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                amount,
                0, // permit nonce for owner
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest); // ATTN: 1 is alice's private key
        bytes4 permitSig = 0xd505accf;

        return abi.encodeWithSelector(permitSig, owner, spender, amount, deadline, v, r, s);
    }

    function _deployInitContracts() internal {
        vm.startPrank(_deployer);

        // deploy L1 contract
        vm.selectFork(_l1Fork);
        address l1EscrowProxy = LibDeployInit.deployL1Contracts();

        // deploy L2 contracts
        vm.selectFork(_l2Fork);
        (address minterBurnerProxy, address nativeConverterProxy) = LibDeployInit.deployL2Contracts();

        // init L1 contract
        vm.selectFork(_l1Fork);
        _l1Escrow = LibDeployInit.initL1Contracts(
            _owner, _admin, _l2NetworkId, _bridge, l1EscrowProxy, minterBurnerProxy, _l1Eurc
        );

        // init L2 contracts
        vm.selectFork(_l2Fork);
        (_minterBurner, _nativeConverter) = LibDeployInit.initL2Contracts(
            _owner,
            _admin,
            _l1NetworkId,
            _bridge,
            l1EscrowProxy,
            minterBurnerProxy,
            nativeConverterProxy,
            _l2Eurc,
            _l2wEURC
        );

        vm.stopPrank();
    }

    function _deployMockBridge() internal virtual {
        vm.selectFork(_l1Fork);
        MockBridge mb1 = new MockBridge();
        bytes memory mb1Code = address(mb1).code;
        vm.etch(_bridge, mb1Code);

        vm.selectFork(_l2Fork);
        MockBridge mb2 = new MockBridge();
        bytes memory mb2Code = address(mb2).code;
        vm.etch(_bridge, mb2Code);
    }

    function _emitDepositBridgeEvent(address receiver, uint256 amount) internal {
        emit Events.BridgeEvent(
            1, // _LEAF_TYPE_MESSAGE
            _l1NetworkId, // Deposit always come from L1
            address(_l1Escrow), // from
            _l2NetworkId, // Deposit always targets L2
            address(_minterBurner), // destinationAddress
            0, // msg.value
            abi.encode(receiver, amount), // metadata
            uint32(MockBridge(_bridge).depositCount())
        );
    }

    function _emitMigrateBridgeEvent() internal {
        uint256 amount = _erc20L2wEURC.balanceOf(address(_nativeConverter));
        address receiver = address(_l1Escrow);

        emit Events.BridgeEvent(
            0, // _LEAF_TYPE_ASSET
            _l1NetworkId, // originNetwork is the origin network of the underlying asset (in this case, L1)
            _l1Eurc, // originTokenAddress
            _l1NetworkId, // destinationNetwork is the target network (L1)
            receiver, // destinationAddress
            amount, // amount
            "", // metadata is empty when bridging wrapped assets
            uint32(MockBridge(_bridge).depositCount())
        );
    }

    function _emitWithdrawBridgeEvent(address receiver, uint256 amount) internal {
        emit Events.BridgeEvent(
            1, // _LEAF_TYPE_MESSAGE
            _l2NetworkId, // Withdraw always come from L2
            address(_minterBurner), // from
            _l1NetworkId, // Withdraw always targets L1
            address(_l1Escrow), // destinationAddress
            0, // msg.value
            abi.encode(receiver, amount), // metadata
            uint32(MockBridge(_bridge).depositCount())
        );
    }

    function _toEURC(uint256 v) internal pure returns (uint256) {
        return v * 10 ** 6;
    }

    function _fundEURC(IEURC eurc, address receiver, uint256 amt) internal {
        vm.prank(eurc.masterMinter());
        eurc.configureMinter(address(this), amt);

        eurc.mint(receiver, amt);
    }
}
