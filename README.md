# EURC LXLY

## Deploy and Initialize
- set up `.env`

- deploy
```
forge script script/DeployInit.s.sol:DeployInit --legacy -vvvv --broadcast
```

- write down resulting addresses for `MinterBurnerProxy` and `NativeEscrowProxy`
> new MinterBurnerProxy@0xe38a08574AFD5E282D6C41EB1E59bF9641c5E648
> new NativeConverterProxy@0x322A0e623999910c6A99F33bcEf98fC1cB9a1bA2

- on L2 EURC, execute the `ConfigureLxLyMinters` script

## Play Around
- check the explorers

| Sepolia | Cardona |
| ------- | ------- |
| [Native EURC](https://sepolia.etherscan.io/address/0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4) | [Native EURC](https://explorer-ui.cardona.zkevm-rpc.com/address/0x73FE5De351321A298a36F3bed7950349E694D5dc)| 
| n/a | [BridgeWrapped EURC](https://explorer-ui.cardona.zkevm-rpc.com/address/0x4738Bd8D019C4bAf0ad6FE51b1b9E8a4512D64fa) |
| [L1Escrow](https://sepolia.etherscan.io/address/0x32882c9b631ef8B5cE7CB07E35C9AA3e8110e02f) | n/a |
| n/a | [MinterBurner](https://explorer-ui.cardona.zkevm-rpc.com/address/0xe38a08574AFD5E282D6C41EB1E59bF9641c5E648) |
| n/a | [NativeEscrow](https://explorer-ui.cardona.zkevm-rpc.com/address/0x322A0e623999910c6A99F33bcEf98fC1cB9a1bA2) |

- get the addresses ready
```
export L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<KEY>
export L2_RPC_URL=https://rpc.cardona.zkevm-rpc.com

export PK=
export TESTER=0xb67826C2176682Fd3Ae3e31A561fc4b9fb012225

export L1_EURC=0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4
export L2_EURC=0x73FE5De351321A298a36F3bed7950349E694D5dc
export L2_BWEURC=0x4738Bd8D019C4bAf0ad6FE51b1b9E8a4512D64fa

export L1_ESCROW=0x32882c9b631ef8B5cE7CB07E35C9AA3e8110e02f
export MINTER_BURNER=0xe38a08574AFD5E282D6C41EB1E59bF9641c5E648
export NATIVE_CONVERTER=0x322A0e623999910c6A99F33bcEf98fC1cB9a1bA2
```

- execute the cast commands
```
# Get Native EURC in L2 through L1Escrow
cast send --rpc-url $L1_RPC_URL --private-key $PK $L1_EURC "approve(address,uint256)" $L1_ESCROW 8000000
cast call $L1_EURC "allowance(address,address)" $TESTER $L1_ESCROW --rpc-url $L1_RPC_URL
cast send --rpc-url $L1_RPC_URL --private-key $PK $L1_ESCROW "bridgeToken(address,uint256,bool)" $TESTER 8000000 true

# Withdraw L2 (Native) EURC into L1 EURC
cast call $L2_EURC "balanceOf(address)" $TESTER --rpc-url $L2_RPC_URL
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $L2_EURC "approve(address,uint256)" $MINTER_BURNER 1000000
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $MINTER_BURNER "bridgeToken(address,uint256,bool)" $TESTER 1000000 true

# Convert BridgeWrapped EURC into Native EURC
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $L2_BWEURC "approve(address,uint256)" $NATIVE_CONVERTER 1000000
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $NATIVE_CONVERTER "convert(address,uint256,bytes)" $TESTER 1000000 ""

# Deconvert Native EURC into BridgeWrapped EURC
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $L2_EURC "approve(address,uint256)" $NATIVE_CONVERTER 1000000
cast send --rpc-url $L2_RPC_URL --legacy --private-key $PK $NATIVE_CONVERTER "deconvert(address,uint256,bytes)" $TESTER 1000000 ""

# Admin Only - Migrate the BridgeWrapped EURC from L2 to L1Escrow
cast send --rpc-url $L2_RPC_URL --private-key $PK $NATIVE_CONVERTER "migrate()"
```
