# ThorchainFramework

`ThorchainFramework` is a native Swift package that can be added to any project which requires client side Thorchain network requests and calculations. 

The framework is designed to work with the Multichain Thorchain network to assist clients in creating  transactions with memo's for Swaps and Staking. Functions are also available to perform Swap/Stake/Slip/Fee calculations for display to users using the latest information from Thorchain node(s) Midgard service.

The framework also safely queries multiple Thorchain nodes for the latest inbound vault addresses which are cached in memory for 15 minutes. For paranoid level security, you should run your own Thorchain node which can be given to the framework to query in addition to other known nodes.

### Dependencies
`BigInt` package is pulled via https://github.com/attaswift/BigInt

### Installation
Use Xcode package manager **Add Package Dependency** and use the Github URL. 

### Usage
```swift
import ThorchainFramework
import BigInt
```
To perform a Swap, Thorchain creates a high level API that performs all network requests and returns transaction and swap calculation info on the main thread via a callback:
```swift
let thorchain = Thorchain(withChain: .testnet)
thorchain.performSwap(fromAsset: .ETH,
                      toAsset: .RuneNative,
                      destinationAddress: "tthor1abcdef...",
                      fromAssetAmount: 0.1) { (swapData) in
    
    if let txParams = swapData?.0, let swapCalculations = swapData?.1 {
        // Success - Current transaction estimates (display to user):
        print(swapCalculations.slip)
        print(swapCalculations.fee)
        print(swapCalculations.output)
        
        // If user chooses to perform transaction, use the
        // following information to perform your transaction:
        switch txParams {
        case .regularSwap(let regularTxData):
            print(regularTxData.amount)
            print(regularTxData.memo)
            print(regularTxData.recipient)
        case .routedSwap(let routedTxData):
            print(routedTxData.routerContractAddress) //use .deposit()
            print(routedTxData.payableVaultAddress)
            print(routedTxData.assetAddress)
            print(routedTxData.amount)
            print(routedTxData.memo)
        }
    }
}
```
Alternatively you can use the lower level functions directly:
```swift
let memo = Thorchain.getSwapMemo(asset: .BTC, destinationAddress: "btc12345", limit: 1234)
// "SWAP:BTC.BTC:btc12345:1234"
```
```swift
let assetInput = AssetAmount(1).baseAmount
let assetPool = Thorchain.PoolData(assetBalance: AssetAmount(110).baseAmount, runeBalance: AssetAmount(100).baseAmount)
var slip : Decimal = Thorchain.getSwapSlip(inputAmount: assetInput, pool: assetPool, toRune: true)
// 0.00900901
```

For Midgard Pool data, ThorchainFramework provides network requests:
```swift
let thorchain = Thorchain(withChain: .testnet)
thorchain.getMidgardPools { (pools) in
    if let pools = pools {
        // Success
        for pool : MidgardPool in pools {
            print(pool.asset)
            print(pool.assetDepth)
            print(pool.runeDepth)
            print(pool.assetPrice)
            print(pool.assetPriceUSD)
            print(pool.poolAPY)
            print(pool.volume24h)
            print(pool.status)
            print(pool.units)
        }
    }
}
```

### Decimals
Thorchain (the network and this framework) uses 1e8 decimals internally for all assets. This means for a *1.0 ETH* transaction, you would interact with the ThorchainFramework with `AssetAmount(1.0)` or `BaseAmount(100_000_000)` (*not* 1e18). When the framework outputs an AssetAmount for you to perform in a live blockchain transaction, you should use the correct number of decimals the real chain requires (e.g. 1e18 for ETH) for your real world transaction.

For very large (or precise) values, do not use float or integer literals in initialisers as the compiler will truncate to `Double`/`Int` precision. Instead, you should initialise large values with a `String` e.g. `Decimal(string: "0.0909090909090909090909")` or `BigInt("4554557182994857123112")`
