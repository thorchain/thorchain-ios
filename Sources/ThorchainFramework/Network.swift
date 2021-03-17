
import Foundation

extension Thorchain {
    
    /// Connect to network, checks health, gets multiple InboundAddress via Midgard proxy `/v2/thorchain/inbound_addresses` and ensures they are all equal, then returns the list via callback.
    /// - Parameter handler: Pass in your completion handler. This will be called on Main Thread with a verified array of active InboundAddress' from the network.
    public func getInboundAddresses(_ completionHandler : @escaping ([InboundAddress]?) -> ()) {
        // Get list of ThorNode's from bootstrap.
        let nodeTask = urlSession.dataTask(with: chain.bootstrapURL) { (data, response, error) in
            assert(Thread.current.isMainThread)  // URLDelegate should be main queue
            guard let data = data, error == nil else {
                if let error = error { print("Thorchain Error: \(error)") }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                    print("Thorchain Error: HTTP \(httpResponse.statusCode) from \(self.chain.bootstrapURL.absoluteString)")
                }
                completionHandler(nil)
                return
            }
            if let nodes : [ThorNode] = try? self.jsonDecoder.decode([ThorNode].self, from: data), nodes.count > 0 {
                // Successful list of IP's. Parse list and get (at most) three common values to check.
                let dispatchGroup = DispatchGroup()
                var validResponses = [[InboundAddress]]()
                let bootstrapSeedURLs = Array(Set(nodes))  // Discard duplicates
                    .compactMap { (nodeIPString) -> URL? in // Create valid URLs and discard invalid results
                        var components = URLComponents()
                        components.host = nodeIPString
                        components.port = Thorchain.Service.midgard.port //8080
                        components.scheme = "http"
                        components.path = "/v2/thorchain/inbound_addresses"
                        return components.url
                    }
                    .chooseRandom(3)
                let trustedMidgardURLs = (self.chain.additionalNodes + self.additionalTrustedMidgardURLs)
                    .map{ $0.appendingPathComponent("/v2/thorchain/inbound_addresses") }
                
                for midgardURL in (bootstrapSeedURLs + trustedMidgardURLs) {
                    dispatchGroup.enter()
                    // Midgard Network Request each node and store valid responses
                    let inboundAddressDataTask = self.urlSession.dataTask(with: midgardURL) { (data, response, error) in
                        defer {
                            dispatchGroup.leave()
                        }
                        guard let data = data, error == nil else {
                            if let error = error { print("Thorchain Error: \(error)") }
                            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                                print("Thorchain Error: HTTP \(httpResponse.statusCode) from \(midgardURL.absoluteString)")
                            }
                            return
                        }
                        if let activeInboundAddresses : [InboundAddress] = try? self.jsonDecoder.decode([InboundAddress].self, from: data)
                            .filter({ $0.halted == false }) {
                            
                            validResponses.append(activeInboundAddresses)
                        }
                    }
                    inboundAddressDataTask.resume()
                }
                
                dispatchGroup.notify(queue: .main) {
                    // All network requests complete (or failed / timed out)
                    // Check all returned InboundAddress' are the same
                    let allMatch : Bool = validResponses.count >= 2 && validResponses.dropFirst().allSatisfy{ $0 == validResponses.first }
                    if allMatch, let activeAddresses = validResponses.first {
                        // All success. Store latest result and signal completion handler also with latest result.
                        self.latestAddressesStored = (activeAddresses, Date())
                        completionHandler(activeAddresses)
                    } else {
                        self.debugLog("Thorchain: Inbound Addresses from various nodes do not match. Aborting")
                        completionHandler(nil)
                    }
                }
            } else {
                self.debugLog("Thorchain: Could not map JSON to InboundAddress model")
                completionHandler(nil)
            }
        }
        nodeTask.resume()
    }
}

// MARK: Midgard

extension Thorchain {
    
    /// GET Pools from Midgard API
    /// - Parameters:
    ///   - completionHandler: Called on main thread. Will contain an array of MidgardPool's, or nil for any errors.
    ///   - midgardAPIURL: (optional) a URL for Midgard. If none specified, uses thorchain.info
    public func getMidgardPools(_ completionHandler: @escaping ([MidgardPool]?) -> (), midgardAPIURL: URL? = nil) {
        let midgardURL : URL
        if let midgardAPIURL = midgardAPIURL {
            midgardURL = midgardAPIURL //user provided
        } else {
            midgardURL = chain.midgardPoolURL  //default
        }
        let midgardApiTask = urlSession.dataTask(with: midgardURL) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Thorchain Error: Midgard API error")
                completionHandler(nil)
                return
            }
            if let pools : [MidgardPool] = try? self.jsonDecoder.decode([MidgardPool].self, from: data), pools.count > 0 {
                completionHandler(pools) //Success
            } else {
                print("Thorchain Error: Could not decode Midgard JSON")
                completionHandler(nil)
            }
        }
        midgardApiTask.resume()
    }
}


// MARK: API Object Mappings

/// Stores an IP address, e.g. "1.2.3.4" or hostname, e.g. "https:// ..."
/// https://testnet.seed.thorchain.info
typealias ThorNode = String



//{
//    "chain": "ETH",
//    "pub_key": "tthorpub1addwnpepqvvxqcz2azdxvrudd93yp6xutf3j76yvw3zup4xpf34vn3knl8nmcy9v8a9",
//    "address": "0xf5c9ba94e1eff689f1ffa318d0229fb25351d66d",
//    "router": "0x9d496De78837f5a2bA64Cb40E62c19FBcB67f55a",
//    "halted": false
//}

/// Inbound Address data returned from Midgard.
public struct InboundAddress : Decodable, Equatable {
    /// Chain, e.g. "ETH"
    public let chain : String
    
    /// Public key
    public let pub_key : String
    
    /// Inbound Vault address. Only valid for a short period of time (~15 mins) due to vault churn. Do not cache.
    public let address : String
    
    /// Normally empty string `""`.
    /// If set, contains ETH router contract address which should be used with the .deposit() function.
    public let router : String
    
    /// Chain is halted. Should be false. Do not use this address if halted is true.
    public let halted : Bool
}




//{
//    "asset": "ETH.USDT-0X62E273709DA575835C7F6AEF4A31140CA5B1D190",
//    "assetDepth": "75858246300",
//    "assetPrice": "4.004465560166793",
//    "assetPriceUSD": "23.80014672779929",
//    "poolAPY": "0.0000655523609780495",
//    "runeDepth": "303771734763",
//    "status": "available",
//    "units": "56506730635",
//    "volume24h": "101341479104"
//}

/// Pool data returned from Midgard
public struct MidgardPool : Decodable {
    public let asset : String  // "BNB.BNB", "ETH.USDT-0X62E273709DA575835C7F6AEF4A31140CA5B1D190" (CAPS)
    public let assetDepth : String // "9059666120" Int64, the amount of Asset in the pool.
    public let assetPrice : String // "27.573749418593366" Float, price of asset in rune. I.e. rune amount / asset amount.
    public let assetPriceUSD : String // "54.42180905385155" Float, the price of asset in USD (based on the deepest USD pool).
    public let poolAPY : String // "30.557039023277234" Float, Average Percentage Yield: annual return estimated using last weeks income, taking compound interest into account.
    public let runeDepth : String // "249808963409" the amount of Rune in the pool.
    public let status : String // "available" The state of the pool, e.g. Available, Staged.
    public let units : String // "255084678018" Int64, Liquidity Units in the pool.
    public let volume24h : String //"39595274504" Int64, the total volume of swaps in the last 24h to and from Rune denoted in Rune.
}


/// Pick up to n random elements from Collection
fileprivate extension Collection {
    func chooseRandom(_ n: Int) -> ArraySlice<Element> { shuffled().prefix(n) }
}
