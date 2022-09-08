// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20 } from "../OpenZeppelin/IERC20.sol";

contract Admin {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferToken(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

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

    function try_renounceOwnership(address exit) external returns (bool ok) {
        string memory sig = "renounceOwnership()";
        (ok,) = address(exit).call(abi.encodeWithSignature(sig));
    }

    function try_mint(address token, address account, uint256 amt) external returns (bool ok) {
        string memory sig = "mint(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_burn(address token, uint256 amt) external returns (bool ok) {
        string memory sig = "burn(uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amt));
    }

    function try_increaseAllowance(address token, address account, uint256 amt) external returns (bool ok) {
        string memory sig = "increaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_decreaseAllowance(address token, address account, uint256 amt) external returns (bool ok) {
        string memory sig = "decreaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_vest(address vesting, address account, uint256 daysUntilVestingBegins, uint256 daysToVest, uint256 amountToVest) external returns (bool ok) {
        string memory sig = "vest(address,uint256,uint256,uint256)";
        (ok,) = address(vesting).call(abi.encodeWithSignature(sig, account, daysUntilVestingBegins, daysToVest, amountToVest));
    }
    
    function try_updateWhitelistedAmplifiers(address amplifier, address account, bool allowed) external returns (bool ok) {
        string memory sig = "updateWhitelistedAmplifiers(address,bool)";
        (ok,) = address(amplifier).call(abi.encodeWithSignature(sig, account, allowed));
    }

    function try_modifyStablecoinWhitelist(address tranches, address asset, bool allowed) external returns (bool ok) {
        string memory sig = "modifyStablecoinWhitelist(address,bool)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, asset, allowed));
    }

    function try_increaseAmplification(address amp, address account, uint256 amt) external returns (bool ok) {
        string memory sig = "increaseAmplification(address,uint256)";
        (ok,) = address(amp).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_decreaseAmplification(address amp, address account, uint256 amt) external returns (bool ok) {
        string memory sig = "decreaseAmplification(address,uint256)";
        (ok,) = address(amp).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_modifyLockerWhitelist(address dao, address locker, bool allowed) external returns (bool ok) {
        string memory sig = "modifyLockerWhitelist(address,bool)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, allowed));
    }

    function try_push(address dao, address locker, address asset, uint256 amount) external returns (bool ok) {
        string memory sig = "push(address,address,uint256)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, amount));
    }

    function try_pull(address dao, address locker, address asset) external returns (bool ok) {
        string memory sig = "pull(address,address)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset));
    }

    function try_pullPartial(address dao, address locker, address asset, uint256 amt) external returns (bool ok) {
        string memory sig = "pullPartial(address,address,uint256)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, amt));
    }

    function try_pushMulti(address dao, address locker, address[] calldata assets, uint256[] calldata amounts) external returns (bool ok) {
        string memory sig = "pushMulti(address,address[],uint256[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, amounts));
    }

    function try_pullMulti(address dao, address locker, address[] calldata assets) external returns (bool ok) {
        string memory sig = "pullMulti(address,address[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets));
    }

    function try_fundLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "fundLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_cancelRequest(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "cancelRequest(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_addReward(address stk, address _rewardsToken, uint256 _rewardsDuration) external returns (bool ok) {
        string memory sig = "addReward(address,uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, _rewardsToken, _rewardsDuration));
    }

    function try_pushAsset(address ret, address asset, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "pushAsset(address,address,uint256)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, to, amount));
    }

    function try_passThroughYDL(address ret, address asset, uint256 amount, address multi) external returns (bool ok) {
        string memory sig = "passThroughYDL(address,uint256,address)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, amount, multi));
    }

    function try_vest(address mrv, address account, uint256 daysToCliff, uint256 daysToVest, uint256 amountToVest, bool revokable) external returns (bool ok) {
        string memory sig = "vest(address,uint256,uint256,uint256,bool)";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig, account, daysToCliff, daysToVest, amountToVest, revokable));
    }

    function try_revoke(address mrv, address account) external returns (bool ok) {
        string memory sig = "revoke(address)";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig, account));
    }
    
    function try_delegate(address zve, address delegatee) external returns (bool ok) {
        string memory sig = "delegate(address)";
        (ok,) = address(zve).call(abi.encodeWithSignature(sig, delegatee));
    }
    
    function try_forwardEmissions(address oce) external returns (bool ok) {
        string memory sig = "forwardEmissions()";
        (ok,) = address(oce).call(abi.encodeWithSignature(sig));
    }

    function try_registerDefault(address ydl,uint256 amount) external returns (bool ok){
        string memory sig = "registerDefault(uint256)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, amount));

    }

}
