
import Foundation
import BigInt

/// Client side calculations, node discovery and network requests used to interact with Thorchain (specifically: Midgard service) in a read-only manner.
/// Real blockchain transactions must be performed elsewhere by the user with the information returned by this service.
/// Initialise with live (or testnet), then call performSwap() to receive latest addresses and all transaction details.
/// Alternatively, query the API static functions such as Thorchain.getSwapSlip() and Thorchain.getSwapMemo() for offline Thorchain support.
/// Use Thorchain on Main Thread only. All functions are non-blocking with asynchronous callbacks that are called back on main thread.
public class Thorchain {
    
    /// Which Thorchain network to connect to
    public enum Chain {
        case mainnet, testnet
        
        /// URL to query for a list of Nodes. In the future this may move to Ethereum contract
        var bootstrapURL : URL {
            switch self {
            case .mainnet:
                return URL(string: "https://seed.thorchain.info")!
            case .testnet:
                return URL(string: "https://testnet.seed.thorchain.info")!
            }
        }
        
        /// Midgard hostnames. Used for all Midgard requests except inbound_addresses which uses various random nodes, plus this.
        var midgardURL : URL {
            switch self {
            case .mainnet:
                return URL(string: "https://midgard.thorchain.info")!
            case .testnet:
                return URL(string: "https://testnet.midgard.thorchain.info")!
            }
        }
    }
    
    /// Defines services and ports
    public enum Service {
        case asgard, midgard
        public var port : Int {
            switch self {
            case .asgard:
                return 1317
            case .midgard:
                return 8080
            }
        }
    }
    
    /// Indicates which chain is being used by this Thorchain instance. Set on init.
    private(set) public var chain = Chain.mainnet
    
    /// Non-public storage of inbound addresses. User should query latestInboundAddresses instead.
    var latestAddressesStored : (inboundAddresses: [Midgard.InboundAddress], fetchedTime: Date)? = nil
    
    /// Latest list of inbound addresses from `/v2/thorchain/inbound_addresses`
    /// If it has been greater than 15 minutes since fetching, this returns nil (you should fetch again)
    public var latestInboundAddresses : [Midgard.InboundAddress]? {
        if let date = latestAddressesStored?.fetchedTime, date.timeIntervalSinceNow >= -15*60,
           let vaults = latestAddressesStored?.inboundAddresses {
            return vaults
        }
        return nil  // No Vault loaded or time greater than 15 mins ago
    }
    
    /// Latest list of pools fetched from `/v2/pools`
    public var latestMidgardPools : [Midgard.Pool]?
    
    /// Shared ephemeral session to use for all network requests. Delegate callbacks on Main Thread. Zero caching.
    let urlSession : URLSession
    
    /// Shared JSON decoder
    let jsonDecoder = JSONDecoder()
    
    /// 3rd party trusted Midgard URLs passed by user. If specified, these will be added to the list of hosts to query which increases trust.
    /// Specify as URL host[:port], e.g. "https://testnet.thornode.thorchain.info". The Thorchain framework will append standard paths "/v2/..." to the hostname/IP.
    /// You would typically only use this if you run your own node for additional security/verification.
    let additionalTrustedMidgardURLs : [URL]
    
    /// Instantiate Thorchain object used to query Thorchain state machine and create memo's for transactions.
    /// - Parameters:
    ///   - chain: Specify chain to use. Default mainnet.
    ///   - additionalTrustedMidgardURLs: (optional) If you run your own node(s), specify here for additional verification. Specify as URL host[:port], e.g. "https://testnet.midgard.thorchain.info". The Thorchain framework will append standard paths e.g. `/v2/thorchain/inbound_addresses` to query the service.
    public init(withChain chain: Chain = .mainnet, additionalTrustedMidgardURLs : [URL] = []) {
        self.chain = chain
        self.additionalTrustedMidgardURLs = additionalTrustedMidgardURLs
        let urlConfiguration = URLSessionConfiguration.ephemeral
        urlConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlConfiguration.timeoutIntervalForRequest = 10
        urlConfiguration.timeoutIntervalForResource = 10
        let networkDelegateQueue = OperationQueue()
        networkDelegateQueue.underlyingQueue = DispatchQueue.main
        urlSession = URLSession(configuration: urlConfiguration, delegate: nil, delegateQueue: networkDelegateQueue)
        mainThreadCheck()
    }
    
    
    /// Calls Midgard API's, uses internal calculations and memo functions to calculate all the required parameters for you to perform an Asset swap using Thorchain.
    /// - Parameters:
    ///   - fromAsset: Asset you are converting FROM. For example .BNB or .BTC.  If this is .RUNE, you must include a toAsset.
    ///   - toAsset: (optional) Asset you are converting TO. If nil or unspecified, this is a "single swap" which converts to RUNE. To perform a "double swap" (fromAsset > RUNE, RUNE > toAsset) specify here. e.g. .ETH
    ///   - destinationAddress: Destination address. This is where the Thorchain nodes will send your output funds. Ensure this is correct and in the format for your toAsset.
    ///   - fromAssetAmount: Amount of your fromAsset you wish to swap. Specified in BaseAmount which is the large unit (e.g. 100000000 for 1.0 BTC). Alternatively use AssetAmount(x, decimal: 8).baseAmount for x units, e.g. 1.0 BTC.
    ///   - completionHandler: Completion handler is called on main thread with an optional TxParams value specifying details of the transaction. You should *not* cache this object for more than 15 minutes. Typically this object is returned to display calculations to the user, who then manually authorises the swap very soon after (if more than 15 minutes, get a fresh TxParams). Use the address and memo in the TxParams to send funds to the appropriate vault or router. For additional validation, you can check that the TxParams address has a large amount of funds in it, indicating it is a valid active vault.
    public func performSwap(fromAsset: Asset,
                            toAsset: Asset = .RuneNative,  //THOR.RUNE
                            destinationAddress: String,
                            fromAssetAmount: AssetAmount,
                            completionHandler: @escaping ( (TxParams, SwapCalculations)? ) -> () ) {
        
        guard fromAsset != toAsset else {
            debugLog("Thorchain: fromAsset and toAsset are the same. Aborting")
            completionHandler(nil)
            return
        }
        
        // Get Inbound addresses
        getInboundAddresses { (inboundAddresses) in
            assert(Thread.current.isMainThread)
            
            // Unwrap result & filter out any chains with status showing 'halted : true'.
            guard let inboundAddresses = inboundAddresses?.filter({ $0.halted ?? false == false }), inboundAddresses.count > 0 else {
                self.debugLog("Thorchain: No inbound addresses found. Probably network error.")
                completionHandler(nil)
                return // Error: No vault. Probably a network error.
            }
            
            self.debugLog("Thorchain: Successfully fetched current inbound addresses")
            
            // TODO: THOR.RUNE > Asset won't find any inbound addresses below because it is done via MsgDeposit. Requires implementing extra logic.
            assert(fromAsset != .RuneNative)
            
            // Get the best Asgard Vault asset address at the last possible time before doing the transaction. An address is good for 15 minutes, but do not cache at all.
            // If a recipient address is cached and funds sent to an old (retired) asgard vault, the funds are lost.
            // If funds are sent to an active vault but your transaction fees are too low and it takes several hours or more, your funds may be lost.
            guard let inboundAddress : Midgard.InboundAddress = inboundAddresses.first(where: { $0.chain.uppercased() == fromAsset.chain.uppercased() }) else {
                self.debugLog("Thorchain: Could not find chain \(fromAsset.chain) in v2/thorchain/inbound_addresses API response")
                completionHandler(nil)
                return
            }
            
            // User selects a pool (list of pools from Midgard, eg BNB pool)
            // Get the RUNE and ASSET balance from Midgard
            // We use Midgard for slip/output/fee calculations because it contains cumulative balances of all current Asgard vaults.
            self.getMidgardPools { (pools) in
                
                guard let pools = pools else {
                    self.debugLog("Thorchain: Could not fetch Midgard pools. Aborting.")
                    completionHandler(nil)
                    return
                }
                
                self.debugLog("Thorchain: Successfully fetched Midgard pools")
                
                if toAsset == .RuneNative || fromAsset == .RuneNative {
                    // Single Swap to/from THOR.RUNE in a single pool.
                                        
                    // Choose which way to go
                    let toRune = (toAsset == .RuneNative)
                    let nonRuneAsset : Asset = toRune ? fromAsset : toAsset
                    
                    // Extract the relevant balance from pools
                    guard let pool : Midgard.Pool = pools.first(where: { $0.asset.uppercased() == nonRuneAsset.memoString.uppercased() }) else {
                        self.debugLog("Thorchain: Could not find Midgard pool for \(nonRuneAsset.memoString). Aborting.")
                        completionHandler(nil)
                        return
                    }
                    
                    // Check Midgard pool status is Available
                    guard pool.status.lowercased() == "available" else {
                        self.debugLog("Thorchain: Midgard reports pool '\(pool.status)'. Must be 'available'. Aborting.")
                        completionHandler(nil)
                        return
                    }
                    
                    // Extract RUNE and nonRuneAsset (e.g. BNB) balances from the pool.
                    let poolRuneBalance = BaseAmount(BigInt(stringLiteral: pool.runeDepth))
                    let poolAssetBalance = BaseAmount(BigInt(stringLiteral: pool.assetDepth))
                    let poolAssets : Thorchain.PoolData = Thorchain.PoolData(assetBalance: poolAssetBalance, runeBalance: poolRuneBalance)
                    
                    // Calculate some items for the user to review (slippage, output, fee)
                    // toRune:  set to 'true' if user is converting asset to RUNE.  false if RUNE to asset.
                    let slip : Decimal = Thorchain.getSwapSlip(inputAmount: fromAssetAmount.baseAmount, pool: poolAssets, toRune: toRune)  //percentage 0.0 - 1.0 (100%)
                    let output : BaseAmount = Thorchain.getSwapOutput(inputAmount: fromAssetAmount.baseAmount, pool: poolAssets, toRune: toRune) //rune (if true), asset (if false). Inclusive of liquidity fees. What you'll *actually* get.
                    let fee : BaseAmount = Thorchain.getSwapFee(inputAmount: fromAssetAmount.baseAmount, pool: poolAssets, toRune: toRune) // fee in whatever unit the output asset is.
                    
                    // Package together in struct ready to send to user.
                    let swapCalculations = SwapCalculations(slip: slip,
                                                            output: output,
                                                            fee: fee,
                                                            assetDepthFirstSwap: poolAssets,
                                                            assetDepthSecondSwap: nil)
                    
                    let swapMemo = Thorchain.getSwapMemo(asset: toAsset, destinationAddress: destinationAddress, limit: BaseAmount(output.amount / 10 * 9))  // * 0.9 protection limit
                    
                    self.debugLog("Thorchain: Successfully calculated Swap parameters\n")
                    self.debugLog("Swapping \(fromAssetAmount.amount.truncate(8)) \(fromAsset.ticker) to \(toAsset.ticker)")
                    self.debugLog("Slip: \((slip*100).truncate(4)) %")
                    self.debugLog("Output (amount of asset received): \(output.assetAmount.amount.truncate(8)) \(toAsset.ticker)")
                    self.debugLog("Fee: \(fee.assetAmount.amount.truncate(4)) RUNE\n")
                    
                    // Check for Router. If one specified, we MUST use this (via .deposit() function) in lieu of the ChainAddress specified.
                    // e.g. https://ropsten.etherscan.io/address/0x9d496De78837f5a2bA64Cb40E62c19FBcB67f55a#code -- Testnet
                    // https://etherscan.io/address/0xc284c7dd4dc9a981f4c0cd2c10da5e91217c3126#code -- Mainnet
                    if let router = inboundAddress.router, router != "" {
                        if fromAsset.chain != "ETH" {
                            // Support for routers other than ETH require correct split (Address) logic above, and testing.
                            self.debugLog("Thorchain: Only ETH Routers supported (tested). Aborting.")
                            completionHandler(nil)
                            return
                        }
                        
                        // Split "TOKEN-0xcontract" into "TOKEN" and "0xcontract"
                        let fromAssetSymbolSplit = fromAsset.symbol.split(separator: "-")
                        let zeroAddress = "0x0000000000000000000000000000000000000000"
                        let assetAddress = fromAssetSymbolSplit.count == 2 ? fromAssetSymbolSplit.last!.lowercased() : zeroAddress  // Use "0xcontract". "ETH" uses "0x0".

                        assert((assetAddress == zeroAddress && fromAsset.memoString == "ETH.ETH") ||        // Should be 0x0 for ETH
                                (fromAsset.chain == "ETH" && fromAsset.symbol != "ETH" && assetAddress.count == 42 && assetAddress.hasPrefix("0x")))  // or a valid ERC20 address
                        
                        // Package up into struct with all info required to call the deposit() function
                        let transactionDetails = TxParams.RoutedTransaction(router: router,
                                                                            payableVaultAddress: inboundAddress.address,
                                                                            assetAddress: String(assetAddress),
                                                                            amount: fromAssetAmount,
                                                                            memo: swapMemo)
                        self.debugLog("Router: \(router)\n")
                        self.debugLog("\n\(router).deposit(\n\tvault: \(transactionDetails.payableVaultAddress ?? "Address expired"),\n\tasset: \(assetAddress), \n\tamount: \(transactionDetails.amount.amount.description) \(fromAsset.ticker),\n\tmemo: \(transactionDetails.memo) \n)\n")
                        
                        let txParams : TxParams = .routedSwap(transactionDetails)
                        completionHandler((txParams, swapCalculations))  // Success
                   
                    } else {
                        let transactionDetails = TxParams.RegularTransaction(recipient: inboundAddress.address, amount: fromAssetAmount, memo: swapMemo)
                        
                        self.debugLog("Recipient: \(transactionDetails.recipient ?? "Recipient address too old")  (do not save/cache for later)")
                        self.debugLog("Amount: \(transactionDetails.amount.amount.truncate(8)) \(fromAsset.ticker)")
                        self.debugLog("Transaction Memo: \(transactionDetails.memo)")
                        
                        let txParams = Thorchain.TxParams.regularSwap(transactionDetails)
                        completionHandler((txParams, swapCalculations))
                    }
                    
                } else {
                    // Double Swap [fromAsset] >> [toAsset]
                    
                    // Extract the relevant balance from pools
                    guard let fromPool : Midgard.Pool = pools.first(where: { $0.asset.uppercased() == fromAsset.memoString.uppercased() }) else {
                        self.debugLog("Thorchain: Could not find Midgard pool for \(fromAsset.memoString). Aborting.")
                        completionHandler(nil)
                        return
                    }
                    guard let toPool : Midgard.Pool = pools.first(where: { $0.asset.uppercased() == toAsset.memoString.uppercased() }) else {
                        self.debugLog("Thorchain: Could not find Midgard pool for \(toAsset.memoString). Aborting.")
                        completionHandler(nil)
                        return
                    }
                    
                    // Check Midgard pool status is Available for both pools
                    guard fromPool.status.lowercased() == "available" && toPool.status.lowercased() == "available" else {
                        self.debugLog("Thorchain: Midgard reports pool status: '\(fromPool.asset): \(fromPool.status), \(toPool.asset): \(toPool.status)'. Aborting.")
                        completionHandler(nil)
                        return
                    }
                    
                    // Extract asset balances from the pools.
                    let fromPoolAssetBalance = BaseAmount(BigInt(stringLiteral: fromPool.assetDepth))
                    let fromPoolRuneBalance = BaseAmount(BigInt(stringLiteral: fromPool.runeDepth))
                    let fromPoolData : Thorchain.PoolData = Thorchain.PoolData(assetBalance: fromPoolAssetBalance, runeBalance: fromPoolRuneBalance)
                    let toPoolAssetBalance = BaseAmount(BigInt(stringLiteral: toPool.assetDepth))
                    let toPoolRuneBalance = BaseAmount(BigInt(stringLiteral: toPool.runeDepth))
                    let toPoolData : Thorchain.PoolData = Thorchain.PoolData(assetBalance: toPoolAssetBalance, runeBalance: toPoolRuneBalance)
                    
                    // Calculate some items for the user to review (slippage, output, fee)
                    let slip : Decimal = Thorchain.getDoubleSwapSlip(inputAmount: fromAssetAmount.baseAmount, pool1: fromPoolData, pool2: toPoolData)
                    let output : BaseAmount = Thorchain.getDoubleSwapOutput(inputAmount: fromAssetAmount.baseAmount, pool1: fromPoolData, pool2: toPoolData)
                    let fee : BaseAmount = Thorchain.getDoubleSwapFee(inputAmount: fromAssetAmount.baseAmount, pool1: fromPoolData, pool2: toPoolData)

                    // Package together in struct ready to send to user.
                    let swapCalculations = SwapCalculations(slip: slip,
                                                            output: output,
                                                            fee: fee,
                                                            assetDepthFirstSwap: fromPoolData,
                                                            assetDepthSecondSwap: toPoolData)
                    
                    let swapMemo = Thorchain.getSwapMemo(asset: toAsset, destinationAddress: destinationAddress, limit: BaseAmount(output.amount / 10 * 9))  // * 0.9 protection limit

                    self.debugLog("Thorchain: Successfully calculated Swap parameters\n")
                    self.debugLog("Swapping \(fromAssetAmount.amount.truncate(8)) \(fromAsset.ticker) to \(toAsset.ticker)")
                    self.debugLog("Slip: \((slip*100).truncate(4)) %")
                    self.debugLog("Output (amount of asset received): \(output.assetAmount.amount.truncate(8)) \(toAsset.ticker)")
                    self.debugLog("Fee: \(fee.assetAmount.amount.truncate(4)) RUNE\n")
                    
                    // Check for Router.
                    if let router = inboundAddress.router, router != "" {
                        if fromAsset.chain != "ETH" {
                            // Support for routers other than ETH require correct split (Address) logic above, and testing.
                            self.debugLog("Thorchain: Only ETH Routers supported (tested). Aborting.")
                            completionHandler(nil)
                            return
                        }

                        // Split "TOKEN-0xcontract" into "TOKEN" and "0xcontract"
                        let fromAssetSymbolSplit = fromAsset.symbol.split(separator: "-")
                        let zeroAddress = "0x0000000000000000000000000000000000000000"
                        let assetAddress = fromAssetSymbolSplit.count == 2 ? fromAssetSymbolSplit.last!.lowercased() : zeroAddress  // Use "0xcontract". "ETH" uses "0x0".

                        assert((assetAddress == zeroAddress && fromAsset.memoString == "ETH.ETH") ||        // Should be 0x0 for ETH
                                (fromAsset.chain == "ETH" && fromAsset.symbol != "ETH" && assetAddress.count == 42 && assetAddress.hasPrefix("0x")))  // or a valid ERC20 address
                        
                        // Package up into struct with all info required to call the deposit() function
                        let transactionDetails = TxParams.RoutedTransaction(router: router,
                                                                            payableVaultAddress: inboundAddress.address,
                                                                            assetAddress: String(assetAddress),
                                                                            amount: fromAssetAmount,
                                                                            memo: swapMemo)
                        
                        self.debugLog("Router: \(router)\n")
                        self.debugLog("\n\(router).deposit(\n\tvault: \(transactionDetails.payableVaultAddress ?? "Address expired"),\n\tasset: \(assetAddress), \n\tamount: \(transactionDetails.amount.amount.description) \(fromAsset.ticker),\n\tmemo: \(transactionDetails.memo) \n)\n")
                        
                        let txParams : TxParams = .routedSwap(transactionDetails)
                        completionHandler((txParams, swapCalculations))  // Success
                   
                    } else {
                        let transactionDetails = TxParams.RegularTransaction(recipient: inboundAddress.address, amount: fromAssetAmount, memo: swapMemo)
                        
                        self.debugLog("Recipient: \(transactionDetails.recipient ?? "Recipient address too old")  (do not save/cache for later)")
                        self.debugLog("Amount: \(transactionDetails.amount.amount.truncate(8)) \(fromAsset.ticker)")
                        self.debugLog("Transaction Memo: \(transactionDetails.memo)")
                        
                        let txParams = Thorchain.TxParams.regularSwap(transactionDetails)
                        completionHandler((txParams, swapCalculations))
                    }
                }
            }
        }
    }

    
    /// Simple debug log - outputs text when in DEBUG builds
    /// - Parameter message: Input string directly "My Message". Are only evaluated if in debug build (for performance).
    func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }

    /// Internal check to warn consumers of this API that we must be on Main Thread.
    private func mainThreadCheck() {
        #if DEBUG
        if !Thread.current.isMainThread {
            print("Thorchain Caution: Please use on Main Thread. All functions are non-blocking with callbacks on main thread")
        }
        #endif
    }
}


extension Thorchain {

    /// Final parameters for a Thorchain transaction. Do not cache because this address is only valid for ~15 minutes.
    /// Warning: Sending crypto to an old recipient from a retired (non-monitored) vault will result in loss of funds.
    /// Always use up to date TxParams
    public enum TxParams {
        case regularSwap(RegularTransaction)
        case routedSwap(RoutedTransaction)
    
        public struct RegularTransaction {
            /// Transaction details. Represents all the information a client needs to perform their transaction into the Thorchain network.
            /// - Parameters:
            ///   - recipient: Address of recipient of transaction. Where to send funds to. Note: Due to frequent vault churns, this is only valid for 15minutes from creation of object. Returns 'nil' for recipient if queried greater than 15mins after creation from the Midgard API request.
            ///   - amount: Base Amount (eg 100000000 for 1.0 BTC)
            ///   - memo: Memo string to attach to the transaction. If an invalid memo string is sent, Thorchain will return the funds (minus a fee).
            public init(recipient: String, amount: AssetAmount, memo: String) {
                self._recipient = recipient
                self.amount = amount
                self.memo = memo
            }
            private let _recipient:  String
            /// Recipient address. Since this is only valid for 15 minutes, it is only returns the address if the time since creation of the txParams is less than 15 minutes old.
            /// If greater than 15 minutes old, returns nil. You should re-query getInboundAddresses() to get a new address.
            /// Before sending funds to this address, you should verify that this address has a large amount of funds in it, indicating it is a current active Asgard vault.
            public var recipient : String? { txCreationDate.timeIntervalSinceNow > -15*60 ? _recipient : nil }
            public let amount : AssetAmount
            public let memo: String
            private let txCreationDate = Date()
        }
        
        
        /// Transaction type that uses a Smart Contract deposit(address payable vault, address asset, uint amount, string memory memo)
        /// For example ETH Router: https://ropsten.etherscan.io/address/0x9d496De78837f5a2bA64Cb40E62c19FBcB67f55a#code
        public struct RoutedTransaction {
            
            /// Transaction details to send to Router smart contracts .deposit() function.
            /// - Parameters:
            ///   - router: Address of Router Smart Contract
            ///   - payableVaultAddress: Payable vault address - the final Asgard vault address (the Router will forward to this)
            ///   - assetAddress: Asset address (e.g. ERC20 Contract Address, or 0x0 for ETH)
            ///   - amount: Base Amount of asset to send
            ///   - memo: Memo string
            public init(router: String, payableVaultAddress: String, assetAddress: String, amount: AssetAmount, memo: String) {
                self.routerContractAddress = router
                self._payableVaultAddress = payableVaultAddress
                self.assetAddress = assetAddress
                self.amount = amount
                self.memo = memo
            }
            
            public let routerContractAddress : String
            private let _payableVaultAddress : String
            public var payableVaultAddress : String? { txCreationDate.timeIntervalSinceNow > -15*60 ? _payableVaultAddress : nil }
            public let assetAddress : String  //0x0 for ETH. 0xabc for ERC20 Contract.
            public let amount : AssetAmount
            public let memo : String
            private let txCreationDate = Date()
        }
    }
    
    /// Contains a list of information to display to the user in order to inform them of an estimated result if they proceed.
    public struct SwapCalculations {
        /// Percentage slippage. 0.0 to 1.0
        public let slip : Decimal
        
        /// Amount of the swap asset they will receive
        public let output : BaseAmount
        
        /// Fee (in RUNE)
        public let fee : BaseAmount
        
        /// Asset depths from Midgard API for the first swap.
        public let assetDepthFirstSwap : Thorchain.PoolData
        
        /// Asset depths from Midgard API for the second swap (if applicable).
        /// Nil for single swap Rune <--> Asset transactions.
        public let assetDepthSecondSwap : Thorchain.PoolData?
    }
}
