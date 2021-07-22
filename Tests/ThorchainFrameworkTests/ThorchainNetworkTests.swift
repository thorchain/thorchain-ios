import XCTest
@testable import ThorchainFramework
@testable import BigInt

final class ThorchainNetworkTests: XCTestCase {
    
    // Used by all tests
    let thorchain = Thorchain(withChain: .mainnet)

    func testSingleSwapRuneToAssetWithNetworking() {
        
        // Create an expectation for a background download task.
        let expectation = XCTestExpectation(description: "Midgard swap request")

        thorchain.performSwap(fromAsset: .RuneNative,
                              toAsset: .BNB,
                              destinationAddress: "tbnb1t3wgptcyp4gyw645w4fh5hpg45wllt2u9q8ns7",
                              fromAssetAmount: 2) { (swapData) in
            
            XCTAssertNotNil(swapData, "No vault data was downloaded.")
            
            if let txParams = swapData?.0, let swapCalculations = swapData?.1 {
                // Success
                print(swapCalculations)
                print(txParams)
                
                XCTAssert(swapCalculations.slip > 0)
                
                switch txParams {
                case .runeNativeDeposit(let runeNativeDeposit):
                    // Or BOND / UNBOND / LEAVE (Node admin typically not supported by 3rd party wallets integrating this framework)
                    XCTAssert(runeNativeDeposit.memo.hasPrefix("SWAP:"))
                default:
                    XCTFail() // Should not get here on this test
                }
            }
            expectation.fulfill()
        }
        
        // Wait until the expectation is fulfilled, with a timeout of 12 seconds.
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testSingleSwapRegularAssetToRuneWithNetworking() {
        
        let expectation = XCTestExpectation(description: "Midgard swap request")

        thorchain.performSwap(fromAsset: .BTC,
                              toAsset: .RuneNative,
                              destinationAddress: "tthor10xgrknu44d83qr4s4uw56cqxg0hsev5e68lc9z",
                              fromAssetAmount: 0.01) { (swapData) in
            
            XCTAssertNotNil(swapData, "No vault data was downloaded.")
            
            if let txParams = swapData?.0, let swapCalculations = swapData?.1 {
                // Success
                print(swapCalculations)
                print(txParams)
                
                XCTAssert(swapCalculations.slip > 0)
                
                switch txParams {
                case .regularSwap(let regularTxData):
                    print(regularTxData)
                    XCTAssert(regularTxData.memo.hasPrefix("SWAP:"))
                default:
                    XCTFail() // Should not get here on this test
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testSingleSwapRoutedAssetToRuneWithNetworking() {
        
        // Create an expectation for a background download task.
        let expectation = XCTestExpectation(description: "Midgard swap request")

        thorchain.performSwap(fromAsset: .ETH,
                              toAsset: .RuneNative,
                              destinationAddress: "tthor10xgrknu44d83qr4s4uw56cqxg0hsev5e68lc9z",
                              fromAssetAmount: 0.1) { (swapData) in
            
            XCTAssertNotNil(swapData, "No vault data was downloaded.")
            
            if let txParams = swapData?.0, let swapCalculations = swapData?.1 {
                // Success
                print(swapCalculations)
                print(txParams)
                
                XCTAssert(swapCalculations.slip > 0)
                
                switch txParams {
                case .routedSwap(let routedTxData):
                    print(routedTxData)
                    if self.thorchain.chain == .testnet {
                        XCTAssert(routedTxData.routerContractAddress.lowercased() == "0xe0a63488e677151844e70623533c22007dc57c9e")
                    }
                    if self.thorchain.chain == .mainnet {
                        XCTAssert(routedTxData.routerContractAddress.lowercased() == "0xc145990e84155416144c532e31f89b840ca8c2ce")
                    }
                    XCTAssert(routedTxData.assetAddress == "0x0000000000000000000000000000000000000000")
                    XCTAssert(routedTxData.memo.hasPrefix("SWAP:"))
                default:
                    XCTFail() // Should not get here on this test
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testDoubleSwapWithNetworking() {
        
        // Create an expectation for a background download task.
        let expectation = XCTestExpectation(description: "Midgard swap request")

        thorchain.performSwap(fromAsset: .BNB,
                              toAsset: .LTC,
                              destinationAddress: "tltc1qjupykwt6fvcrrn8z44m8edlc2d6qq0ytw85ydh",
                              fromAssetAmount: 1) { (swapData) in
            
            XCTAssertNotNil(swapData, "No vault data was downloaded.")
            
            if let txParams = swapData?.0, let swapCalculations = swapData?.1 {
                // Success
                print(swapCalculations)
                print(txParams)
                
                XCTAssert(swapCalculations.slip > 0)
                
                switch txParams {
                case .regularSwap(let regularTxData):
                    print(regularTxData)
                    XCTAssert(regularTxData.memo.hasPrefix("SWAP:"))
                default:
                    XCTFail() // Should not get here on this test
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    // MARK: - Midgard API
    // Testing real network API responses map to API objects and return non-nil results.
    
    func testMidgardHealthRequest() {
        let expectation = XCTestExpectation(description: "Midgard health request")
        thorchain.getMidgardHealthInfo { (health) in
            XCTAssertNotNil(health)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardPoolsRequest() {
        let expectation = XCTestExpectation(description: "Midgard pools request")
        thorchain.getMidgardPools { (pools) in
            XCTAssertNotNil(pools)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardPoolRequest() {
        let expectation = XCTestExpectation(description: "Midgard pool request")
        thorchain.getMidgardPool(asset: "BTC.BTC") { (pool) in
            XCTAssertNotNil(pool)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardPoolStatisticsRequest() {
        let expectation = XCTestExpectation(description: "Midgard pool statistics request")
        thorchain.getMidgardPoolStatistics(asset: "BTC.BTC") { (stats) in
            XCTAssertNotNil(stats)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardDepthPriceHistoryRequest() {
        let expectation = XCTestExpectation(description: "Midgard depth history request")
        thorchain.getMidgardDepthPriceHistory(pool:"BTC.BTC") { (history) in
            XCTAssertNotNil(history)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardEarningsHistoryRequest() {
        let expectation = XCTestExpectation(description: "Midgard earnings history request")
        thorchain.getMidgardEarningsHistory { (history) in
            XCTAssertNotNil(history)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardSwapsHistoryRequest() {
        let expectation = XCTestExpectation(description: "Midgard swaps history request")
        thorchain.getMidgardSwapsHistory(pool: "BTC.BTC") { (history) in
            XCTAssertNotNil(history)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardLiquidityChangesHistoryRequest() {
        let expectation = XCTestExpectation(description: "Midgard liquidity changes history request")
        thorchain.getMidgardLiquidityChangesHistory { (history) in
            XCTAssertNotNil(history)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardNodesRequest() {
        let expectation = XCTestExpectation(description: "Midgard nodes request")
        thorchain.getMidgardNodes { (nodes) in
            XCTAssertNotNil(nodes)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardNetworkRequest() {
        let expectation = XCTestExpectation(description: "Midgard network request")
        thorchain.getMidgardNetworkData { (networkData) in
            XCTAssertNotNil(networkData)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardActionsRequest() {
        let expectation = XCTestExpectation(description: "Midgard action request")
        thorchain.getMidgardActions(limit: 5, offset: 0) { (action) in
            XCTAssertNotNil(action)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    func testMidgardMembersRequest() {
        let expectation = XCTestExpectation(description: "Midgard members request")
        thorchain.getMidgardMembers { (members) in
            XCTAssertNotNil(members)
            XCTAssert(members!.count > 0)
            let randomMember = members!.randomElement()!
            self.thorchain.getMidgardMember(address: randomMember) { (member) in
                XCTAssertNotNil(member)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testMidgardGlobalStatsRequest() {
        let expectation = XCTestExpectation(description: "Midgard global stats request")
        thorchain.getMidgardGlobalStats { (stats) in
            XCTAssertNotNil(stats)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    
    // MARK: - Midgard API (Thorchain proxied requests)
    
    func testThorchainConstantsRequest() {
        let expectation = XCTestExpectation(description: "Midgard Thorchain Constants request")
        thorchain.getThorchainConstants { (constants) in
            XCTAssertNotNil(constants)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testThorchainLastBlockRequest() {
        let expectation = XCTestExpectation(description: "Midgard Thorchain LastBlock request")
        thorchain.getThorchainLastBlock { (lastBlock) in
            XCTAssertNotNil(lastBlock)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
    func testThorchainQueueRequest() {
        let expectation = XCTestExpectation(description: "Midgard Thorchain Queue request")
        thorchain.getThorchainQueue { (queue) in
            XCTAssertNotNil(queue)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 12.0)
    }
    
}
