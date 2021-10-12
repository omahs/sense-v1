// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import { ERC20 } from "solmate/erc20/ERC20.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { DateTimeFull } from "./test-helpers/DateTimeFull.sol";

import { TestHelper } from "./test-helpers/TestHelper.sol";
import { Errors } from "../libs/errors.sol";
import { Divider } from "../Divider.sol";
import { Token } from "../tokens/Token.sol";

contract Dividers is TestHelper {
    using FixedMath for uint256;
    using Errors for string;

    Divider.Backfill[] backfills;

    /* ========== initSeries() tests ========== */

    function testCantInitSeriesNotEnoughStakeBalance() public {
        uint256 balance = stable.balanceOf(address(alice));
        alice.doTransfer(address(stable), address(bob), balance - INIT_STAKE / 2);
        uint256 maturity = getValidMaturity(2021, 10);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.TransferFromFailed);
        }
    }

    function testCantInitSeriesNotEnoughStakeAllowance() public {
        alice.doApprove(address(stable), address(divider), 0);
        uint256 maturity = getValidMaturity(2021, 10);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.TransferFromFailed);
        }
    }

    function testCantInitSeriesFeedNotEnabled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        divider.setFeed(address(feed), false);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantInitSeriesIfAlreadyExists() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.DuplicateSeries);
        }
    }

    function testCantInitSeriesActiveSeriesReached() public {
        uint256 SERIES_TO_INIT = 3;
        for (uint256 i = 1; i <= SERIES_TO_INIT; i++) {
            uint256 nextMonthDate = DateTimeFull.addMonths(block.timestamp, i);
            nextMonthDate = getValidMaturity(DateTimeFull.getYear(nextMonthDate), DateTimeFull.getMonth(nextMonthDate));
            (address zero, address claim) = initSampleSeries(address(alice), nextMonthDate);
            hevm.warp(block.timestamp + 1 days);
            assertTrue(address(zero) != address(0));
            assertTrue(address(claim) != address(0));
        }
        uint256 lastDate = DateTimeFull.addMonths(block.timestamp, SERIES_TO_INIT + 1);
        lastDate = getValidMaturity(DateTimeFull.getYear(lastDate), DateTimeFull.getMonth(lastDate));
        try alice.doInitSeries(address(feed), lastDate) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidMaturity);
        }
    }

    function testCantInitSeriesWithMaturityBeforeTimestamp() public {
        uint256 maturity = DateTimeFull.timestampFromDateTime(2021, 8, 1, 0, 0, 0);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidMaturity);
        }
    }

    function testCantInitSeriesLessThanMinMaturity() public {
        hevm.warp(1631923200);
        // 18-09-21 00:00 UTC
        uint256 maturity = DateTimeFull.timestampFromDateTime(2021, 10, 1, 0, 0, 0);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidMaturity);
        }
    }

    function testCantInitSeriesMoreThanMaxMaturity() public {
        hevm.warp(1631664000);
        // 15-09-21 00:00 UTC
        uint256 maturity = DateTimeFull.timestampFromDateTime(2022, 1, 1, 0, 0, 0);
        try alice.doInitSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidMaturity);
        }
    }

    function testInitSeries() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, address claim) = initSampleSeries(address(alice), maturity);
        assertTrue(zero != address(0));
        assertTrue(claim != address(0));
        assertEq(ERC20(zero).name(), "Compound Dai 10-2021 Zero by Sense");
        assertEq(ERC20(zero).symbol(), "zcDAI:10-2021");
        assertEq(ERC20(claim).name(), "Compound Dai 10-2021 Claim by Sense");
        assertEq(ERC20(claim).symbol(), "ccDAI:10-2021");
    }

    function testInitSeriesWithdrawStake() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 beforeBalance = stable.balanceOf(address(alice));
        (address zero, address claim) = initSampleSeries(address(alice), maturity);
        assertTrue(address(zero) != address(0));
        assertTrue(address(claim) != address(0));
        uint256 afterBalance = stable.balanceOf(address(alice));
        assertEq(afterBalance, beforeBalance - INIT_STAKE);
    }

    function testInitThreeSeries() public {
        uint256 SERIES_TO_INIT = 3;
        for (uint256 i = 1; i <= SERIES_TO_INIT; i++) {
            uint256 nextMonthDate = DateTimeFull.addMonths(block.timestamp, i);
            nextMonthDate = getValidMaturity(DateTimeFull.getYear(nextMonthDate), DateTimeFull.getMonth(nextMonthDate));
            (address zero, address claim) = initSampleSeries(address(alice), nextMonthDate);
            hevm.warp(block.timestamp + 1 days);
            assertTrue(address(zero) != address(0));
            assertTrue(address(claim) != address(0));
        }
    }

    function testInitSeriesOnMinMaturity() public {
        hevm.warp(1631664000);
        // 15-09-21 00:00 UTC
        uint256 maturity = DateTimeFull.timestampFromDateTime(2021, 10, 1, 0, 0, 0);
        initSampleSeries(address(alice), maturity);
    }

    function testInitSeriesOnMaxMaturity() public {
        hevm.warp(1631664000);
        // 15-09-21 00:00 UTC
        uint256 maturity = DateTimeFull.timestampFromDateTime(2021, 12, 1, 0, 0, 0);
        initSampleSeries(address(alice), maturity);
    }

    /* ========== settleSeries() tests ========== */

    function testCantSettleSeriesIfDisabledFeed() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        divider.setFeed(address(feed), false);
        try alice.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantSettleSeriesAlreadySettled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        try alice.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.AlreadySettled);
        }
    }

    function testCantSettleSeriesIfNotSponsorAndSponsorWindow() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        try bob.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.OutOfWindowBoundaries);
        }
    }

    function testCantSettleSeriesIfNotSponsorCutoffTime() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW + 1 seconds));
        try bob.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.OutOfWindowBoundaries);
        }
    }

    function testCantSettleSeriesIfSponsorAndCutoffTime() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW + 1 seconds));
        try alice.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.OutOfWindowBoundaries);
        }
    }

    function testCantSettleSeriesIfNotSponsorAndSponsorTime() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW - 1 minutes));
        try bob.doSettleSeries(address(feed), maturity) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.OutOfWindowBoundaries);
        }
    }

    function testSettleSeries() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesIfSponsorAndSponsorWindow() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesIfSponsorAndOnSponsorWindowMinLimit() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.subSeconds(maturity, SPONSOR_WINDOW));
        alice.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesIfSponsorAndOnSponsorWindowMaxLimit() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW));
        alice.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesIfSponsorAndSettlementWindow() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW));
        alice.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesIfNotSponsorAndSettlementWindow() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW));
        bob.doSettleSeries(address(feed), maturity);
    }

    function testSettleSeriesStakeIsTransferredIfSponsor() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 beforeBalance = stable.balanceOf(address(alice));
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        uint256 afterBalance = stable.balanceOf(address(alice));
        assertEq(beforeBalance, afterBalance);
    }

    function testSettleSeriesStakeIsTransferredIfNotSponsor() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 beforeBalance = stable.balanceOf(address(bob));
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + 1 seconds));
        bob.doSettleSeries(address(feed), maturity);
        uint256 afterBalance = stable.balanceOf(address(bob));
        assertEq(afterBalance, beforeBalance + INIT_STAKE);
    }

    //    function testSettleSeriesFeesAreTransferredIfSponsor() public {
    //        revert("IMPLEMENT");
    //    }
    //
    //    function testSettleSeriesFeesAreTransferredIfNotSponsor() public {
    //        revert("IMPLEMENT");
    //    }

    /* ========== issue() tests ========== */

    function testCantIssueFeedDisabled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        divider.setFeed(address(feed), false);
        try alice.doIssue(address(feed), maturity, tBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantIssueSeriesDoesntExists() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try alice.doIssue(address(feed), maturity, tBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SeriesDoesntExists);
        }
    }

    function testCantIssueNotEnoughBalance() public {
        uint256 aliceBalance = target.balanceOf(address(alice));
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        divider.setGuard(address(target), aliceBalance * 2);
        try alice.doIssue(address(feed), maturity, aliceBalance + 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.TransferFromFailed);
        }
    }

    function testCantIssueNotEnoughAllowance() public {
        uint256 aliceBalance = target.balanceOf(address(alice));
        alice.doApprove(address(target), address(divider), 0);
        divider.setGuard(address(target), aliceBalance);
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        try alice.doIssue(address(feed), maturity, aliceBalance) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.TransferFromFailed);
        }
    }

    function testCantIssueIfSeriesSettled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        uint256 amount = target.balanceOf(address(alice));
        try alice.doIssue(address(feed), maturity, amount) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.IssueOnSettled);
        }
    }

    function testCantIssueIfFeedValueLowerThanPrevious() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        (, uint256 lvalue) = feed.lscale();
        feed.setScale(lvalue - 1);
        hevm.warp(block.timestamp + 1 days);
        try feed.scale() {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidScaleValue);
        }
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try alice.doIssue(address(feed), maturity, tBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidScaleValue);
        }
    }

    function testCantIssueIfMoreThanCap() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        uint256 amount = divider.guards(address(target)) + 1;
        try alice.doIssue(address(feed), maturity, amount) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.GuardCapReached);
        }
    }

    function testIssue(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, address claim) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 convertBase = 1;
        uint256 tDecimals = target.decimals();
        if (tDecimals != 18) {
            convertBase = tDecimals < 18 ? 10**(18 - tDecimals) : 10**(tDecimals - 18);
        }
        uint256 tBase = 10**target.decimals();
        uint256 fee = (ISSUANCE_FEE / convertBase).fmul(tBal, tBase); // 1 target
        uint256 tBalanceBefore = target.balanceOf(address(alice));
        alice.doIssue(address(feed), maturity, tBal);
        // Formula = newBalance.fmul(scale)
        (, uint256 lscale) = feed.lscale();
        uint256 mintedAmount = (tBal - fee).fmul(lscale, Token(zero).BASE_UNIT());
        assertEq(ERC20(zero).balanceOf(address(alice)), mintedAmount);
        assertEq(ERC20(claim).balanceOf(address(alice)), mintedAmount);
        assertEq(target.balanceOf(address(alice)), tBalanceBefore - tBal);
    }

    //    function testIssueTwoTimes() public {
    //        revert("IMPLEMENT");
    //    }

    /* ========== combine() tests ========== */

    function testCantCombineFeedDisabled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        divider.setFeed(address(feed), false);
        try alice.doCombine(address(feed), maturity, tBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantCombineSeriesDoesntExists() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try alice.doCombine(address(feed), maturity, tBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SeriesDoesntExists);
        }
    }

    function testCantCombineIfFeedValueLowerThanPrevious() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, ) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        alice.doIssue(address(feed), maturity, tBal);
        uint256 zBal = ERC20(zero).balanceOf(address(alice));
        (, uint256 lvalue) = feed.lscale();
        feed.setScale(lvalue - 1);
        hevm.warp(block.timestamp + 1 days);
        try alice.doCombine(address(feed), maturity, zBal) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidScaleValue);
        }
    }

    //    function testCantCombineNotEnoughBalance() public {
    //        revert("IMPLEMENT");
    //    }
    //
    //    function testCantCombineNotEnoughAllowance() public {
    //        revert("IMPLEMENT");
    //    }

    function testCombine(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, address claim) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        uint256 zBalanceBefore = ERC20(zero).balanceOf(address(bob));
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        bob.doCombine(address(feed), maturity, zBalanceBefore);
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        uint256 zBalanceAfter = ERC20(zero).balanceOf(address(bob));
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));
        require(zBalanceAfter == 0);
        require(cBalanceAfter == 0);
        assertClose((tBalanceAfter - tBalanceBefore).fmul(lscale, Token(zero).BASE_UNIT()), zBalanceBefore);
        // Amount of Zeros before combining == underlying balance
        // uint256 collected = ??
        // assertEq(tBalanceAfter - tBalanceBefore, collected); // TODO: assert collected value
    }

    function testCombineAtMaturity(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, address claim) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        uint256 zBalanceBefore = ERC20(zero).balanceOf(address(bob));

        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);

        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        bob.doCombine(address(feed), maturity, zBalanceBefore);
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        uint256 zBalanceAfter = ERC20(zero).balanceOf(address(bob));
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));

        require(zBalanceAfter == 0);
        require(cBalanceAfter == 0);
        //        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertClose((tBalanceAfter - tBalanceBefore).fmul(lscale, Token(zero).BASE_UNIT()), zBalanceBefore);
        // TODO: check if this is correct!! Should it be .fmul(mscale));
        // Amount of Zeros before combining == underlying balance
        // uint256 collected = ??
        // assertEq(tBalanceAfter - tBalanceBefore, collected); // TODO: assert collected value
    }

    /* ========== redeemZero() tests ========== */
    function testCantRedeemZeroDisabledFeed() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, ) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        divider.setFeed(address(feed), false);
        uint256 balance = ERC20(zero).balanceOf(address(alice));
        try alice.doRedeemZero(address(feed), maturity, balance) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantRedeemZeroSeriesDoesntExists() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 balance = 1e18;
        try alice.doRedeemZero(address(feed), maturity, balance) {
            fail();
        } catch Error(string memory error) {
            // The settled check will fail if the Series does not exist
            assertEq(error, Errors.NotSettled);
        }
    }

    function testCantRedeemZeroSeriesNotSettled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, ) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(block.timestamp + 1 days);
        uint256 balance = ERC20(zero).balanceOf(address(bob));
        try bob.doRedeemZero(address(feed), maturity, balance) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.NotSettled);
        }
    }

    function testCantRedeemZeroMoreThanBalance() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, ) = initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        uint256 balance = ERC20(zero).balanceOf(address(alice)) + 1e18;
        try alice.doRedeemZero(address(feed), maturity, balance) {
            fail();
        } catch (bytes memory error) {
            // Does not return any error message
        }
    }

    function testRedeemZero(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (address zero, ) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 zBalanceBefore = ERC20(zero).balanceOf(address(bob));
        uint256 balanceToRedeem = zBalanceBefore;
        bob.doRedeemZero(address(feed), maturity, balanceToRedeem);
        uint256 zBalanceAfter = ERC20(zero).balanceOf(address(bob));

        // Formula: tBal = balance / mscale
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        uint256 redeemed = balanceToRedeem.fdiv(mscale, Token(zero).BASE_UNIT());
        // Amount of Zeros burned == underlying amount
        assertClose(redeemed.fmul(mscale, Token(zero).BASE_UNIT()), zBalanceBefore);
        assertEq(zBalanceBefore, zBalanceAfter + balanceToRedeem);
    }

    function testRedeemZeroBalanceIsZero() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        alice.doSettleSeries(address(feed), maturity);
        uint256 tBalanceBefore = target.balanceOf(address(alice));
        uint256 balance = 0;
        alice.doRedeemZero(address(feed), maturity, balance);
        uint256 tBalanceAfter = target.balanceOf(address(alice));
        assertEq(tBalanceAfter, tBalanceBefore);
    }

    //    function testCanRedeemZeroBeforeMaturityIfSettled() public {
    //        revert("IMPLEMENT");
    //    }

    /* ========== collect() tests ========== */

    function testCantCollectDisabledFeed() public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        divider.setFeed(address(feed), false);
        try alice.doCollect(claim) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidFeed);
        }
    }

    function testCantCollectIfMaturityAndNotSettled(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(maturity + divider.SPONSOR_WINDOW() + 1);
        try bob.doCollect(claim) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.CollectNotSettled);
        }
    }

    //    function testCantCollectIfNotClaimContract() public {
    //        revert("IMPLEMENT");
    //    }

    function testCollect(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        uint256 claimBaseUnit = Token(claim).BASE_UNIT();
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(block.timestamp + 1 days);
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        uint256 cBalanceBefore = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        uint256 collected = bob.doCollect(claim);
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceAfter = target.balanceOf(address(bob));

        // Formula: collect = tBal / lscale - tBal / cscale
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        (, uint256 lvalue) = feed.lscale();
        uint256 cscale = block.timestamp >= maturity ? mscale : lvalue;
        uint256 collect = cBalanceBefore.fdiv(lscale, claimBaseUnit);
        collect -= cBalanceBefore.fdiv(cscale, claimBaseUnit);
        assertEq(cBalanceBefore, cBalanceAfter);
        assertEq(collected, collect);
        assertEq(tBalanceAfter, tBalanceBefore + collected); // TODO: double check!
    }

    function testCollectAtMaturityBurnClaimsAndDoesNotCallBurnTwice(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        uint256 claimBaseUnit = Token(claim).BASE_UNIT();
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(maturity);
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        uint256 cBalanceBefore = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        alice.doSettleSeries(address(feed), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 collected = bob.doCollect(claim);
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        (, uint256 lvalue) = feed.lscale();
        uint256 cscale = block.timestamp >= maturity ? mscale : lvalue;
        // Formula: collect = tBal / lscale - tBal / cscale
        uint256 collect = cBalanceBefore.fdiv(lscale, claimBaseUnit);
        collect -= cBalanceBefore.fdiv(cscale, claimBaseUnit);
        assertEq(collected, collect);
        assertEq(cBalanceAfter, 0);
        assertEq(tBalanceAfter, tBalanceBefore + collected); // TODO: double check!
    }

    function testCollectBeforeMaturityAfterEmergencyDoesNotReplaceBackfilled(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        divider.setFeed(address(feed), false); // emergency stop
        uint256 newScale = 20e17;
        divider.backfillScale(address(feed), maturity, newScale, backfills); // fix invalid scale value
        divider.setFeed(address(feed), true); // re-enable feed after emergency
        bob.doCollect(claim);
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertEq(mscale, newScale);
        // TODO: check .scale() is not called (like to add the lscale). We can't?
    }

    function testCollectBeforeMaturityAndSettled(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        uint256 claimBaseUnit = Token(claim).BASE_UNIT();
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(maturity - SPONSOR_WINDOW);
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        uint256 cBalanceBefore = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        alice.doSettleSeries(address(feed), maturity);
        hevm.warp(block.timestamp + 1 days);
        uint256 collected = bob.doCollect(claim);
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        (, uint256 lvalue) = feed.lscale();
        uint256 cscale = block.timestamp >= maturity ? mscale : lvalue;
        // Formula: collect = tBal / lscale - tBal / cscale
        uint256 collect = cBalanceBefore.fdiv(lscale, claimBaseUnit);
        collect -= cBalanceBefore.fdiv(cscale, claimBaseUnit);
        assertEq(collected, collect);
        assertEq(cBalanceAfter, 0);
        assertEq(tBalanceAfter, tBalanceBefore + collected); // TODO: double check!
    }

    function testCollectTransferAndCollect(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        uint256 claimBaseUnit = Token(claim).BASE_UNIT();
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(block.timestamp + 15 days);
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        uint256 acBalanceBefore = ERC20(claim).balanceOf(address(alice));
        uint256 bcBalanceBefore = ERC20(claim).balanceOf(address(bob));
        uint256 btBalanceBefore = target.balanceOf(address(bob));
        bob.doTransfer(address(claim), address(alice), bcBalanceBefore); // collects and transfer
        uint256 btBalanceAfter = target.balanceOf(address(bob));
        uint256 bcollected = btBalanceAfter - btBalanceBefore;
        uint256 acollected = alice.doCollect(claim); // try to collect

        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        (, uint256 lvalue) = feed.lscale();
        uint256 cscale = block.timestamp >= maturity ? mscale : lvalue;
        // Formula: collect = tBal / lscale - tBal / cscale
        uint256 collect = bcBalanceBefore.fdiv(lscale, claimBaseUnit);
        collect -= bcBalanceBefore.fdiv(cscale, claimBaseUnit);
        assertEq(bcollected, collect);
        assertEq(ERC20(claim).balanceOf(address(alice)), bcBalanceBefore);
        assertEq(ERC20(claim).balanceOf(address(bob)), 0);
        assertEq(btBalanceAfter, btBalanceBefore + bcollected);
        assertEq(acollected, 0);
    }

    function testCollectTransferToMyselfAndCollect(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address claim) = initSampleSeries(address(alice), maturity);
        uint256 claimBaseUnit = Token(claim).BASE_UNIT();
        hevm.warp(block.timestamp + 1 days);
        uint256 tBase = 10**target.decimals();
        bob.doIssue(address(feed), maturity, tBal);
        hevm.warp(block.timestamp + 15 days);
        uint256 lscale = divider.lscales(address(feed), maturity, address(bob));
        uint256 cBalanceBefore = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        bob.doTransfer(address(claim), address(bob), cBalanceBefore); // collects and transfer
        uint256 cBalanceAfter = ERC20(claim).balanceOf(address(bob));
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        uint256 collected = tBalanceAfter - tBalanceBefore;
        uint256 collectedAfterTransfer = alice.doCollect(claim); // try to collect

        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        (, uint256 lvalue) = feed.lscale();
        uint256 cscale = block.timestamp >= maturity ? mscale : lvalue;
        // Formula: collect = tBal / lscale - tBal / cscale
        uint256 collect = cBalanceBefore.fdiv(lscale, claimBaseUnit);
        collect -= cBalanceBefore.fdiv(cscale, claimBaseUnit);
        assertEq(collected, collect);
        assertEq(cBalanceAfter, cBalanceBefore);
        assertEq(tBalanceAfter, tBalanceBefore + collected);
        assertEq(collectedAfterTransfer, 0);
    }

    /* ========== backfillScale() tests ========== */
    function testCantBackfillScaleSeriesDoesntExists() public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try divider.backfillScale(address(feed), maturity, tBal, backfills) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SeriesDoesntExists);
        }
    }

    function testCantBackfillScaleBeforeCutoffAndFeedEnabled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try divider.backfillScale(address(feed), maturity, tBal, backfills) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.OutOfWindowBoundaries);
        }
    }

    function testCantBackfillScaleSeriesNotGov() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW + 1 seconds));
        uint256 tBase = 10**target.decimals();
        uint256 tBal = 100 * tBase;
        try alice.doBackfillScale(address(feed), maturity, tBal, backfills) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.NotAuthorized);
        }
    }

    function testCantBackfillScaleInvalidValue() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW + 1 seconds));
        uint256 amount = 1 * (10**(target.decimals() - 2));
        try divider.backfillScale(address(feed), maturity, amount, backfills) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.InvalidScaleValue);
        }
    }

    function testBackfillScale() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(DateTimeFull.addSeconds(maturity, SPONSOR_WINDOW + SETTLEMENT_WINDOW + 1 seconds));
        uint256 newScale = 1e18;
        Divider.Backfill memory aliceBackfill = Divider.Backfill(address(alice), 5e17);
        Divider.Backfill memory bobBackfill = Divider.Backfill(address(bob), 4e17);
        backfills.push(aliceBackfill);
        backfills.push(bobBackfill);
        divider.backfillScale(address(feed), maturity, newScale, backfills);
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertEq(mscale, newScale);
        uint256 lscale = divider.lscales(address(feed), maturity, address(alice));
        assertEq(lscale, aliceBackfill.lscale);
        lscale = divider.lscales(address(feed), maturity, address(bob));
        assertEq(lscale, bobBackfill.lscale);
    }

    function testBackfillScaleBeforeCutoffAndFeedDisabled() public {
        uint256 maturity = getValidMaturity(2021, 10);
        initSampleSeries(address(alice), maturity);
        hevm.warp(maturity);
        divider.setFeed(address(feed), false);
        uint256 newScale = 1e18;
        divider.backfillScale(address(feed), maturity, newScale, backfills);
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertEq(mscale, newScale);
    }

    // @notice if backfill happens before the maturity and sponsor window, stablecoin stake is transferred to the
    // sponsor and issuance fees are returned to Sense's cup multisig address
    function testBackfillScaleBeforeSponsorWindowTransfersStablecoinStakeAndFees(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 cupTargetBalanceBefore = target.balanceOf(address(this));
        uint256 cupStableBalanceBefore = stable.balanceOf(address(this));
        uint256 sponsorTargetBalanceBefore = target.balanceOf(address(alice));
        uint256 sponsorStableBalanceBefore = stable.balanceOf(address(alice));
        initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);

        uint256 convertBase = 1;
        uint256 tDecimals = target.decimals();
        if (target.decimals() != 18) {
            convertBase = tDecimals < 18 ? 10**(18 - tDecimals) : 10**(tDecimals - 18);
        }
        uint256 tBase = 10**tDecimals;
        uint256 fee = (ISSUANCE_FEE / convertBase).fmul(tBal, tBase); // 1 target
        bob.doIssue(address(feed), maturity, tBal);

        hevm.warp(maturity - SPONSOR_WINDOW);
        divider.setFeed(address(feed), false);
        uint256 newScale = 1 * tBase;
        divider.backfillScale(address(feed), maturity, newScale, backfills);
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertEq(mscale, newScale);
        assertEq(target.balanceOf(address(alice)), sponsorTargetBalanceBefore);
        assertEq(stable.balanceOf(address(alice)), sponsorStableBalanceBefore);
        assertEq(target.balanceOf(address(this)), cupTargetBalanceBefore + fee);
        assertEq(stable.balanceOf(address(this)), cupStableBalanceBefore);
    }

    // @notice if backfill happens after issuance fees are returned to Sense's cup multisig address, both issuance fees
    // and the stablecoin stake will go to Sense's cup multisig address
    function testBackfillScaleAfterSponsorBeforeSettlementWindowsTransfersStablecoinStakeAndFees(uint96 tBal) public {
        uint256 maturity = getValidMaturity(2021, 10);
        uint256 sponsorTargetBalanceBefore = target.balanceOf(address(alice));
        uint256 sponsorStableBalanceBefore = stable.balanceOf(address(alice));
        uint256 cupTargetBalanceBefore = target.balanceOf(address(this));
        uint256 cupStableBalanceBefore = stable.balanceOf(address(this));
        initSampleSeries(address(alice), maturity);
        hevm.warp(block.timestamp + 1 days);

        uint256 convertBase = 1;
        uint256 tDecimals = target.decimals();
        if (tDecimals != 18) {
            convertBase = tDecimals < 18 ? 10**(18 - tDecimals) : 10**(tDecimals - 18);
        }
        uint256 tBase = 10**tDecimals;
        uint256 fee = (ISSUANCE_FEE / convertBase).fmul(tBal, tBase); // 1 target
        bob.doIssue(address(feed), maturity, tBal);

        hevm.warp(maturity + SPONSOR_WINDOW + 1 seconds);
        divider.setFeed(address(feed), false);
        uint256 newScale = 1 * tBase;
        divider.backfillScale(address(feed), maturity, newScale, backfills);
        (, , , , , , uint256 mscale) = divider.series(address(feed), maturity);
        assertEq(mscale, newScale);
        uint256 sponsorTargetBalanceAfter = target.balanceOf(address(alice));
        uint256 sponsorStableBalanceAfter = stable.balanceOf(address(alice));
        assertEq(sponsorTargetBalanceAfter, sponsorTargetBalanceBefore);
        assertEq(sponsorStableBalanceAfter, sponsorStableBalanceBefore - INIT_STAKE);
        uint256 cupTargetBalanceAfter = target.balanceOf(address(this));
        uint256 cupStableBalanceAfter = stable.balanceOf(address(this));
        assertEq(cupTargetBalanceAfter, cupTargetBalanceBefore + fee);
        assertEq(cupStableBalanceAfter, cupStableBalanceBefore + INIT_STAKE);
    }

    /* ========== misc tests ========== */

    //    function testFeedIsDisabledIfScaleValueLowerThanPrevious() public {
    //    }

    //    function testFeedIsDisabledIfScaleValueCallReverts() public {
    //        revert("IMPLEMENT");
    //    }

    //    function testFeedIsDisabledIfScaleValueHigherThanThanPreviousPlusDelta() public {
    //        revert("IMPLEMENT");
    //    }
}
