import XCTest
@testable import ThorchainFramework
@testable import BigInt

// Approximate equality for rounding errors at the least significant digit
// This is acceptable precision for client side swap/fee/output estimates
infix operator ~==
func ~==(lhs: BigInt, rhs: BigInt) -> Bool {
    return abs(lhs - rhs) <= 1
}
func ~==(lhs: Decimal, rhs: Decimal) -> Bool {
    return lhs == rhs || lhs.nextUp == rhs || lhs.nextDown == rhs
}

final class ThorchainFrameworkTests: XCTestCase {
    
    /// We test to ensure all URLs hard-coded with force unwrap in framework will not cause runtime crashes
    func testURLs() {
        XCTAssert(URL(string: "https://seed.thorchain.info") != nil)
        XCTAssert(URL(string: "https://testnet-seed.thorchain.info") != nil)
        XCTAssert(URL(string: "https://chaosnet-seed.thorchain.info") != nil)
        XCTAssert(URL(string: "https://testnet.thornode.thorchain.info") != nil)
        XCTAssert(URL(string: "https://testnet.midgard.thorchain.info/v2/pools") != nil)
        XCTAssert(URL(string: "https://midgard.thorchain.info") != nil)
    }
    
    func testAssets() {
        let oneRune = AssetAmount(1.5)
        XCTAssert(oneRune.baseAmount.amount == BaseAmount(150000000).amount)
        
        let tor = BaseAmount(150_000_000)
        XCTAssert(tor.assetAmount.amount == 1.5)
        
        let bigEth = AssetAmount(Decimal(string: "4554.557182994857123112")!, decimal: 18)
        let wei = BaseAmount(BigInt("4554557182994857123112"), decimal: 18)
        XCTAssert(bigEth.baseAmount.amount.description == "4554557182994857123112")
        XCTAssert(bigEth.baseAmount.amount == BigInt("4554557182994857123112"))
        XCTAssert(wei.amount.description == "4554557182994857123112")
        XCTAssert(wei.assetAmount.amount.description == "4554.557182994857123112")
        XCTAssert(wei.assetAmount.amount == Decimal(string: "4554.557182994857123112"))
    }
    
    // Memo output tests as per https://gitlab.com/thorchain/asgardex-common/asgardex-util/-/blob/master/src/memo.test.ts
    // Trailing colons have been added to some of these tests for consistency
    func testMemos() {
        /* Swap Memo's */
        
        // memo to swap BNB
        let memo1 = Thorchain.getSwapMemo(asset: Thorchain.Asset.BNB, destinationAddress: "bnb123", limit: 1234)
        XCTAssert(memo1 == "SWAP:BNB.BNB:bnb123:1234")
        
        // memo for an empty address -- Test not implemented here as this framework has chosen to not support empty destination addresses.
//        let memo2 = Thorchain.getSwapMemo(asset: .BNB, limit: 1234)
//        XCTAssert(memo2 == "SWAP:BNB.BNB::1234")
        
        // memo w/o limit
        let memo3 = Thorchain.getSwapMemo(asset: .BNB, destinationAddress: "bnb123")
        XCTAssert(memo3 == "SWAP:BNB.BNB:bnb123:")
        
        // memo w/o address and w/o limit -- Test not implemented here as this framework has chosen to not support empty destination addresses.
//        let memo4 = Thorchain.getSwapMemo(asset: .BNB)
//        XCTAssert(memo4 == "SWAP:BNB.BNB::")
        
        // memo to swap RUNE
        let memo5 = Thorchain.getSwapMemo(asset: .RuneB1A, destinationAddress: "bnb123", limit: 1234)
        XCTAssert(memo5 == "SWAP:BNB.RUNE-B1A:bnb123:1234")
        
        // memo to swap BTC
        let memo6 = Thorchain.getSwapMemo(asset: .BTC, destinationAddress: "btc123", limit: 1234)
        XCTAssert(memo6 == "SWAP:BTC.BTC:btc123:1234")
        
        /* Deposit Memo's */
        
        // memo to deposit BNB
        let memo7 = Thorchain.getDepositMemo(asset: .BNB)
        XCTAssert(memo7 == "ADD:BNB.BNB:")
        
        // memo to deposit RUNE
        let memo8 = Thorchain.getDepositMemo(asset: .RuneB1A)
        XCTAssert(memo8 == "ADD:BNB.RUNE-B1A:")
        
        // memo to deposit BTC
        let memo9 = Thorchain.getDepositMemo(asset: .BTC)
        XCTAssert(memo9 == "ADD:BTC.BTC:")
    
        // memo to deposit BTC with cross-referenced address
        let memo10 = Thorchain.getDepositMemo(asset: .BTC, address: "bnb123")
        XCTAssert(memo10 == "ADD:BTC.BTC:bnb123")
        
        /* Withdrawal Memo's */
        
        // memo to withdraw BNB
        let memo11 = Thorchain.getWithdrawMemo(asset: .BNB, percent: 11)
        XCTAssert(memo11 == "WITHDRAW:BNB.BNB:1100:")
        
        // memo to withdraw RUNE
        let memo12 = Thorchain.getWithdrawMemo(asset: .RuneNative, percent: 22)
        XCTAssert(memo12 == "WITHDRAW:THOR.RUNE:2200:")
        
        // memo to withdraw BTC
        let memo13 = Thorchain.getWithdrawMemo(asset: .BTC, percent: 33)
        XCTAssert(memo13 == "WITHDRAW:BTC.BTC:3300:")
        
        // memo to withdraw (asym) BTC
        let memo14 = Thorchain.getWithdrawMemo(asset: .BTC, percent: 100, targetAsset: .BTC)
        XCTAssert(memo14 == "WITHDRAW:BTC.BTC:10000:BTC.BTC")
        
        // memo to withdraw (asym) RUNE
        let memo15 = Thorchain.getWithdrawMemo(asset: .BTC, percent: 100, targetAsset: .RuneNative)
        XCTAssert(memo15 == "WITHDRAW:BTC.BTC:10000:THOR.RUNE")
        
        // adjusts percent to 100 if percent > 100
        let memo16 = Thorchain.getWithdrawMemo(asset: .BTC, percent: 101)
        XCTAssert(memo16 == "WITHDRAW:BTC.BTC:10000:")
        
        // adjusts negative number of percent to 0
        let memo17 = Thorchain.getWithdrawMemo(asset: .BTC, percent: -10)
        XCTAssert(memo17 == "WITHDRAW:BTC.BTC:0:")
        
        /* Misc Memo's */
        
        // memo to withdraw BNB
        let memo18 = Thorchain.getSwitchMemo(address: "tthor123")
        XCTAssert(memo18 == "SWITCH:tthor123")
        
        // memo to bond
        let memo19 = Thorchain.getBondMemo(thorAddress: "tthor123")
        XCTAssert(memo19 == "BOND:tthor123")
        
        // memo to unbond from BaseAmount units value
        let memo20 = Thorchain.getUnbondMemo(thorAddress: "tthor123", units: 1000)
        XCTAssert(memo20 == "UNBOND:tthor123:1000")
        
        // memo to leave
        let memo21 = Thorchain.getLeaveMemo(thorAddress: "tthor123")
        XCTAssert(memo21 == "LEAVE:tthor123")
    }
    
    // https://gitlab.com/thorchain/asgardex-common/asgardex-util/-/blob/master/src/calc/stake.test.ts
    func testStakeCalculations() {
        let assetPoolBefore = Thorchain.PoolData(
            assetBalance: AssetAmount(110).baseAmount,
            runeBalance: AssetAmount(100).baseAmount
        )
        let stakeData = Thorchain.StakeData(asset: AssetAmount(11).baseAmount, rune: AssetAmount(10).baseAmount)
        let assetPoolAfter = Thorchain.PoolData(
            assetBalance: AssetAmount(121).baseAmount,
            runeBalance: AssetAmount(110).baseAmount
        )
        let unitData = Thorchain.UnitData(stakeUnits: AssetAmount(10.5).baseAmount, totalUnits: AssetAmount(115.5).baseAmount)
        let poolShare = Thorchain.StakeData(asset: AssetAmount(11).baseAmount, rune: AssetAmount(10).baseAmount)

        let assetPool2Before = Thorchain.PoolData(
            assetBalance: AssetAmount(110).baseAmount,
            runeBalance: AssetAmount(100).baseAmount
        )
        let stakeData2 = Thorchain.StakeData(asset: AssetAmount(0).baseAmount, rune: AssetAmount(10).baseAmount)
        let assetPool2After = Thorchain.PoolData(assetBalance: AssetAmount(110).baseAmount, runeBalance: AssetAmount(110).baseAmount)
        let unitData2 = Thorchain.UnitData(stakeUnits: AssetAmount(5).baseAmount, totalUnits: AssetAmount(110).baseAmount)
        let poolShare2 = Thorchain.StakeData(asset: AssetAmount(5).baseAmount, rune: AssetAmount(5).baseAmount)
        let stakeData3 = Thorchain.StakeData(asset: AssetAmount(20).baseAmount, rune: AssetAmount(0).baseAmount)

        // Stake calc
        // Symmetric Stake Event
        // Correctly gets Stake Units
        var units = Thorchain.getStakeUnits(stake: stakeData, pool: assetPoolBefore)
        XCTAssert(units.amount == unitData.stakeUnits.amount)

        // Correctly gets Pool Share
        var poolShare_ = Thorchain.getPoolShare(unitData: unitData, pool: assetPoolAfter)
        XCTAssert(poolShare_.asset.amount == poolShare.asset.amount)
        XCTAssert(poolShare_.rune.amount == poolShare.rune.amount)

        // Asymmetric Stake Event
        // Correctly gets Stake Units
        units = Thorchain.getStakeUnits(stake: stakeData2, pool: assetPool2Before)
        XCTAssert(units.amount == unitData2.stakeUnits.amount)

        // Correctly gets Slip On Stake
        var slip : Decimal = Thorchain.getSlipOnStake(stake: stakeData2, pool: assetPool2Before)
        var slipRounded : Decimal = 0
        NSDecimalRound(&slipRounded, &slip, 8, .plain)
        XCTAssert(slipRounded == Decimal(string: "0.09090909"))

        // Correctly gets Slip on Stake2
        slip = Thorchain.getSlipOnStake(stake: stakeData3, pool: assetPool2Before)
        NSDecimalRound(&slipRounded, &slip, 8, .plain)
        XCTAssert(slipRounded == Decimal(string: "0.18181818"))

        // Correctly gets Pool Share
        poolShare_ = Thorchain.getPoolShare(unitData: unitData2, pool: assetPool2After)
        XCTAssert(poolShare_.asset.amount == poolShare2.asset.amount)
        XCTAssert(poolShare_.rune.amount == poolShare2.rune.amount)
    }
    
    // https://gitlab.com/thorchain/asgardex-common/asgardex-util/-/blob/master/src/calc/swap.test.ts
    func testSwapCalculations() {
        let assetPool = Thorchain.PoolData(assetBalance: AssetAmount(110).baseAmount, runeBalance: AssetAmount(100).baseAmount)
        let usdPool = Thorchain.PoolData(assetBalance: AssetAmount(10).baseAmount, runeBalance: AssetAmount(100).baseAmount)
        let assetInput = AssetAmount(1).baseAmount
        let runeInput = AssetAmount(1).baseAmount
        let assetOutput = AssetAmount(0.89278468).baseAmount
        let usdOutput = AssetAmount(0.08770544).baseAmount

        // Swap Calc
        // Single Swaps

        // Gets Correct output
        var output = Thorchain.getSwapOutput(inputAmount: assetInput, pool: assetPool, toRune: true)
        XCTAssert(output.amount ~== assetOutput.amount)  //89278467 vs 89278468

        // Gets correct output with fee
        output = Thorchain.getSwapOutputWithFee(inputAmount: assetInput, pool: assetPool, toRune: false)
        XCTAssert(output.amount <= 0)

        // Gets correct input
        let input = Thorchain.getSwapInput(toRune: true, pool: assetPool, outputAmount: assetOutput)
        XCTAssert(input.amount == assetInput.amount)

        // Gets correct slip
        var output2 : Decimal = Thorchain.getSwapSlip(inputAmount: assetInput, pool: assetPool, toRune: true)
        var resultRounded : Decimal = 0
        NSDecimalRound(&resultRounded, &output2, 8, .plain)
        XCTAssert(resultRounded == Decimal(string: "0.00900901"))  //Equal to 8 digits

        // Gets correct fee
        output = Thorchain.getSwapFee(inputAmount: assetInput, pool: assetPool, toRune: true)
        var expected = AssetAmount(0.00811622).amount
        XCTAssert(output.assetAmount.amount == expected)  // Equal to 8 digits

        // Gets correct value of asset in RUNE
        output = Thorchain.getValueOfAssetInRune(inputAsset: assetInput, pool: assetPool)
        expected = AssetAmount(Decimal(string: "0.9090909")!).amount
        XCTAssert(output.assetAmount.amount ~== expected)  // Equal to 8 digits:  0.9090909 vs 0.90909091

        // Gets correct value of rune in asset
        output = Thorchain.getValueOfRuneInAsset(inputRune: runeInput, pool: assetPool)
        expected = AssetAmount(1.1).amount
        XCTAssert(output.assetAmount.amount == expected)

        // Double Swaps

        // Gets correct output
        output = Thorchain.getDoubleSwapOutput(inputAmount: assetInput, pool1: assetPool, pool2: usdPool)
        expected = AssetAmount(Decimal(string: "0.08770544")!).amount
        XCTAssert(output.assetAmount.amount ~== expected) // 0.08770543 vs 0.08770544
        
        // Gets correct input
        let output3 = Thorchain.getDoubleSwapInput(pool1: assetPool, pool2: usdPool, outputAmount: usdOutput)
        var expected2 = AssetAmount(1.00000005).baseAmount
        XCTAssert(output3.amount == expected2.amount)
        XCTAssert("\(output3.amount)" == "\(expected2.amount)")

        // Gets correct output with fee
        output = Thorchain.getDoubleSwapOutputWithFee(inputAmount: assetInput, pool1: assetPool, pool2: usdPool)
        expected2 = AssetAmount(Decimal(string: "-0.01054038")!).baseAmount
        XCTAssert(output.amount ~== expected2.amount) // -1054039 vs -1054038

        // Gets correct slip
        do {
            var slip1 = Thorchain.getSwapSlip(inputAmount: assetInput, pool: assetPool, toRune: true)
            var slip1Rounded : Decimal = 0
            NSDecimalRound(&slip1Rounded, &slip1, 8, .plain)
            let expected1 = Decimal(string: "0.00900901")
            XCTAssert(slip1Rounded == expected1)
            let r = Thorchain.getSwapOutput(inputAmount: assetInput, pool: assetPool, toRune: true)
            var slip2 = Thorchain.getSwapSlip(inputAmount: r, pool: usdPool, toRune: false)
            var slip2Rounded : Decimal = 0
            NSDecimalRound(&slip2Rounded, &slip2, 8, .plain)
            let expected2 = Decimal(string: "0.00884885")
            XCTAssert(slip2Rounded == expected2)
            var output = Thorchain.getDoubleSwapSlip(inputAmount: assetInput, pool1: assetPool, pool2: usdPool)
            var outputRounded : Decimal = 0
            NSDecimalRound(&outputRounded, &output, 8, .plain)
            let expected3 = Decimal(string: "0.01785785")
            XCTAssert(outputRounded == expected3)
        }

        // Gets correct fee
        do {
            let fee1 = Thorchain.getSwapFee(inputAmount: assetInput, pool: assetPool, toRune: true)
            let expected1 = AssetAmount(0.00811622).amount
            XCTAssert(fee1.assetAmount.amount == expected1)
            let r = Thorchain.getSwapOutput(inputAmount: assetInput, pool: assetPool, toRune: true)
            let fee2 = Thorchain.getSwapFee(inputAmount: r, pool: usdPool, toRune: false)
            let expected2 = AssetAmount(0.00078302).amount
            XCTAssert(fee2.assetAmount.amount == expected2)  // Agree to 8 decimals
            let output = Thorchain.getDoubleSwapFee(inputAmount: assetInput, pool1: assetPool, pool2: usdPool)
            let expected = AssetAmount(Decimal(string: "0.00159464")!).amount
            XCTAssert(output.assetAmount.amount == expected)
        }

        // Gets correct value of Asset1 in USD

        do {
            let output = Thorchain.getValueOfAsset1InAsset2(inputAsset: assetInput, pool1: assetPool, pool2: usdPool)
            let expected = AssetAmount(0.09090909).baseAmount
            XCTAssert(output.amount == expected.amount)
            XCTAssert("\(output.amount)" == "\(expected.amount)")
        }
        
    }

    static var allTests = [
        ("testURLs", testURLs),
        ("testAssets", testAssets),
        ("testMemos", testMemos),
        ("testStakeCalculations", testStakeCalculations),
        ("testSwapCalculations", testSwapCalculations),
    ]
}
