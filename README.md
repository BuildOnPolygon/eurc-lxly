# EURC LXLY

## Deploy and Initialize

1. set up `.env`

2. deploy

```shell
forge script script/DeployInit.s.sol:DeployInit --multi --legacy -vvvv --verify --etherscan-api-key <> --broadcast
```

3. write down resulting addresses for `MinterBurnerProxy` and `NativeEscrowProxy`

> new MinterBurnerProxy@0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
>
> new NativeConverterProxy@0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

4. on L2 EURC, execute the `ConfigureLxLyMinters` script

## Play Around

- check the explorers

| Eth Mainnet                                                                            | ZkEVM Mainnet                                                                                          |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| [Native EURC](https://etherscan.io/address/0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c) | [EURC.e](https://zkevm.polygonscan.com/address/0x48ffd6616857ab5883487268ef3f1c78dde870e3)             |
| n/a                                                                                    | [BridgeWrapped EURC](https://zkevm.polygonscan.com/address/0x514723aCd1e233C2523E512Fa6af1eD4fad102E0) |
| [L1Escrow](https://etherscan.io/address/0xbc35bd9a7f1fb02d297e5bf3005f949b8c1a0f91)    | n/a                                                                                                    |
| n/a                                                                                    | [MinterBurner](https://zkevm.polygonscan.com/address/0xdcdbeb3e5a9e41b3f8ef43e44eee429a29fdc407)       |
| n/a                                                                                    | [NativeEscrow](https://zkevm.polygonscan.com/address/0xee6fcf42d78b9a642637e372061096619f94d446)       |

| Sepolia                                                                                        | Cardona                                                                                                            |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [Native EURC](https://sepolia.etherscan.io/address/0x08210F9170F89Ab7658F0B5E3fF39b0E03C594D4) | [EURC.e](https://explorer-ui.cardona.zkevm-rpc.com/address/0x73FE5De351321A298a36F3bed7950349E694D5dc)             |
| n/a                                                                                            | [BridgeWrapped EURC](https://explorer-ui.cardona.zkevm-rpc.com/address/0x4738Bd8D019C4bAf0ad6FE51b1b9E8a4512D64fa) |
| [L1Escrow](https://sepolia.etherscan.io/address/0x32882c9b631ef8B5cE7CB07E35C9AA3e8110e02f)    | n/a                                                                                                                |
| n/a                                                                                            | [MinterBurner](https://explorer-ui.cardona.zkevm-rpc.com/address/0xe38a08574AFD5E282D6C41EB1E59bF9641c5E648)       |
| n/a                                                                                            | [NativeEscrow](https://explorer-ui.cardona.zkevm-rpc.com/address/0x322A0e623999910c6A99F33bcEf98fC1cB9a1bA2)       |

- get the addresses ready

```
export L1_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/<XXXXX>
export L2_RPC_URL=https://zkevm-rpc.com

export PK=
export TESTER=0x02023f74ED12Df7752144aE8A23411776D4698b4

export L1_EURC=0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c
export L2_EURC=0x48ffd6616857ab5883487268eF3F1c78dde870e3
export L2_BWEURC=0x514723aCd1e233C2523E512Fa6af1eD4fad102E0

export L1_ESCROW=0x937d0003df039C9685bf0E4A6b3dd50FE0d719B0
export MINTER_BURNER=0xEF502e776367fbb5Bd17b9b36A1750cd30aEbf2B
export NATIVE_CONVERTER=0xa841f406e7E4fcCe2C9f3Da219D62BF6245bdf0B
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
