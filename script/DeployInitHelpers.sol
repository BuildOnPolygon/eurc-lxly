// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";

import {CommonBase} from "lib/forge-std/src/Base.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1Escrow.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverter.sol";
import "../src/MinterBurnerProxy.sol";
import "../src/MinterBurner.sol";

/// @title LibDeployInit
/// @dev A helper library that implements the logic for deploying
/// the LXLY system contracts
library LibDeployInit {
    function deployL1Contracts() internal returns (address l1eProxy) {
        // deploy implementation
        L1Escrow l1Escrow = new L1Escrow();
        console.log("L1Escrow implementation address=%s", address(l1Escrow));

        // deploy proxy
        L1EscrowProxy l1EscrowProxy = new L1EscrowProxy(address(l1Escrow), "");
        console.log("L1Escrow proxy address=%s", address(l1EscrowProxy));

        // return address of the proxy
        l1eProxy = address(l1EscrowProxy);
    }

    function deployL2Contracts() internal returns (address mbProxy, address ncProxy) {
        // deploy implementation
        MinterBurner minterBurnerImpl = new MinterBurner();
        console.log("MinterBurner implementation address=%s", address(minterBurnerImpl));

        // deploy proxy
        MinterBurnerProxy minterBurnerProxy = new MinterBurnerProxy(address(minterBurnerImpl), "");
        console.log("ZKMinterBurner proxy address=%s", address(minterBurnerProxy));

        // deploy implementation
        NativeConverter nativeConverter = new NativeConverter();
        console.log("NativeConverter implementation address=%s", address(nativeConverter));

        // deploy proxy
        NativeConverterProxy nativeConverterProxy = new NativeConverterProxy(address(nativeConverter), "");
        console.log("NativeConverter proxy address=%s", address(nativeConverterProxy));

        // return addresses of the proxies
        mbProxy = address(minterBurnerProxy);
        ncProxy = address(nativeConverterProxy);
    }

    function initL1Contracts(
        address owner,
        address admin,
        uint32 l2NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address l1Eurc
    ) internal returns (L1Escrow l1Escrow) {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        l1Escrow = L1Escrow(l1EscrowProxy);
        l1Escrow.initialize(owner, admin, bridge, l2NetworkId, minterBurnerProxy, l1Eurc);
    }

    function initL2Contracts(
        address owner,
        address admin,
        uint32 l1NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address nativeConverterProxy,
        address zkEURC,
        address zkBWEURC
    ) internal returns (MinterBurner minterBurner, NativeConverter nativeConverter) {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        minterBurner = MinterBurner(minterBurnerProxy);
        minterBurner.initialize(owner, admin, bridge, l1NetworkId, l1EscrowProxy, zkEURC);

        // get a reference to the proxy, with the impl's abi, and then call initialize
        nativeConverter = NativeConverter(nativeConverterProxy);
        nativeConverter.initialize(owner, admin, bridge, l1NetworkId, l1EscrowProxy, zkEURC, zkBWEURC);
    }
}
