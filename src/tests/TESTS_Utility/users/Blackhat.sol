// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;
pragma experimental ABIEncoderV2;

import "../../../libraries/OpenZeppelin/IERC20.sol";

contract Blackhat {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferByTrader(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_transferToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_transferFromToken(address token, address from, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transferFrom(address,address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, from, to, amt));
    }

    function try_approveToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

   function try_changeMinterRole(address token, address account, bool allowed) external returns (bool ok) {
        string memory sig = "changeMinterRole(address,bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, allowed));
    }

    function try_burn(address token, uint amt) external returns (bool ok) {
        string memory sig = "burn(uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amt));
    }

    function try_burnSenior(address token, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "burnSenior(uint256,address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_mint(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "mint(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_vest(address vesting, address account, uint256 daysUntilVestingBegins, uint256 daysToVest, uint256 amountToVest) external returns (bool ok) {
        string memory sig = "vest(address,uint256,uint256,uint256)";
        (ok,) = address(vesting).call(abi.encodeWithSignature(sig, account, daysUntilVestingBegins, daysToVest, amountToVest));
    }
    
    function try_updateWhitelistedAmplifiers(address amplifier, address account, bool allowed) external returns (bool ok) {
        string memory sig = "updateWhitelistedAmplifiers(address,uint256,uint256,uint256)";
        (ok,) = address(amplifier).call(abi.encodeWithSignature(sig, account, allowed));
    }

    function try_increaseAmplification(address amp, address account, uint amt) external returns (bool ok) {
        string memory sig = "increaseAmplification(address,uint256)";
        (ok,) = address(amp).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_increaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "increaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_decreaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "decreaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_modifyStablecoinWhitelist(address tranches, address asset, bool allowed) external returns (bool ok) {
        string memory sig = "modifyStablecoinWhitelist(address,bool)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, asset, allowed));
    }

    function try_depositJunior(address ito, uint256 amt, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amt, asset));
    }

    function try_depositSenior(address ito, uint256 amt, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amt, asset));
    }

    function try_claim(address ito) external returns (bool ok) {
        string memory sig = "claim()";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig));
    }

    function try_migrateDeposits(address ito) external returns (bool ok) {
        string memory sig = "migrateDeposits()";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig));
    }

    function try_depositJuniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSeniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_updateIsKeeper(address gbl, address keeper, bool allowed) external returns (bool ok) {
        string memory sig = "updateIsKeeper(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, keeper, allowed));
    }

    function try_updateIsLocker(address gbl, address locker, bool allowed) external returns (bool ok) {
        string memory sig = "updateIsLocker(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, locker, allowed));
    }

    function try_updateStablecoinWhitelist(address gbl, address stablecoin, bool allowed) external returns (bool ok) {
        string memory sig = "updateStablecoinWhitelist(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, stablecoin, allowed));
    }

    function try_push(address dao, address locker, address asset, uint256 amount) external returns (bool ok) {
        string memory sig = "push(address,address,uint256)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, amount));
    }

    function try_pull(address dao, address locker, address asset) external returns (bool ok) {
        string memory sig = "pullMulti(address,address)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset));
    }

    function try_requestLoan(
        address occ, 
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        int8 schedule
    ) external returns (bool ok) {
        string memory sig = "requestLoan(uint256,uint256,uint256,uint256,uint256,int8)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, borrowAmount, APR, APRLateFee, term, paymentInterval, schedule));
    }

    function try_cancelRequest(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "cancelRequest(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_fundLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "fundLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_makePayment(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "makePayment(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_callLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "callLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_markDefault(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markDefault(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveInsolvency(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveInsolvency(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_supplyInterest(address occ, uint256 id, uint256 excessAmount) external returns (bool ok) {
        string memory sig = "supplyInterest(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, excessAmount));
    }

    function try_pushAsset(address ret, address asset, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "pushAsset(address,address,uint256)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, to, amount));
    }

    function try_passThroughYDL(address ret, address asset, uint256 amount, address multi) external returns (bool ok) {
        string memory sig = "passThroughYDL(address,uint256,address)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, amount, multi));
    }

    function try_revoke(address mrv, address account) external returns (bool ok) {
        string memory sig = "revoke(address)";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig, account));
    }

    function try_exchange_underlying(address pool, int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (bool ok) {
        string memory sig = "exchange_underlying(int128,int128,uint256,uint256)";
        (ok,) = address(pool).call(abi.encodeWithSignature(sig, i, j, dx, min_dy));
    }

    function try_increaseDefaults(address gen, uint256 amount) external returns (bool ok){
        string memory sig = "increaseDefaults(uint256)";
        (ok,) = address(gen).call(abi.encodeWithSignature(sig, amount));
    }

    function try_decreaseDefaults(address gen, uint256 amount) external returns (bool ok){
        string memory sig = "decreaseDefaults(uint256)";
        (ok,) = address(gen).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMaxTrancheRatio(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMaxTrancheRatio(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMinZVEPerJTTMint(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMinZVEPerJTTMint(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMaxZVEPerJTTMint(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMaxZVEPerJTTMint(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateLowerRatioIncentive(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateLowerRatioIncentive(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateUpperRatioIncentives(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateUpperRatioIncentives(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    
}