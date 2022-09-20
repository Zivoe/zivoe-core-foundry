// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;
pragma experimental ABIEncoderV2;

import "../../../libraries/OpenZeppelin/IERC20.sol";

import { IZivoeITO } from "../../../misc/InterfacesAggregated.sol";

contract TrancheLiquidityProvider {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferToken(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    function transferByTrader(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    function view_amountWithdrawableSeniorBurn(address ito, address asset) external returns (uint256) {
        return IZivoeITO(ito).amountWithdrawableSeniorBurn(asset);
    }

    function claimAidrop(address ito) external returns (uint256, uint256, uint256) {
        return IZivoeITO(ito).claim();
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferByTrader(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_approveToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }    

    function try_depositJunior(address ito, uint256 amt, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amt, asset));
    }

    function try_depositSenior(address ito, uint256 amt, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amt, asset));
    }
    function try_supplementYield(address ydl, uint256 amount) external returns (bool ok){
        string memory sig = "supplementYield(uint256)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, amount));
    }
    function try_claim(address ito) external returns (bool ok) {
        string memory sig = "claim()";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig));
    }
    
    function try_burnSenior(address token, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "burnSenior(uint256,address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount, asset));
    }
    
    function try_claim(address vesting, address account) external returns (bool ok) {
        string memory sig = "claim(address)";
        (ok,) = address(vesting).call(abi.encodeWithSignature(sig, account));
    }

    function try_mint(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "mint(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }
    
    function try_modifyStablecoinWhitelist(address tranches, address asset, bool allowed) external returns (bool ok) {
        string memory sig = "modifyStablecoinWhitelist(address,bool)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, asset, allowed));
    }

    function try_depositJuniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSeniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_claimTrancheTokens(address tranches) external returns (bool ok) {
        string memory sig = "claim()";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig));
    }

    function try_stake(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "stake(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_withdraw(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "withdraw(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_fullWithdraw(address stk) external returns (bool ok) {
        string memory sig = "fullWithdraw()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }

    function try_getRewards(address stk) external returns (bool ok) {
        string memory sig = "getRewards()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }
    
    function try_delegate(address zve, address delegatee) external returns (bool ok) {
        string memory sig = "delegate(address)";
        (ok,) = address(zve).call(abi.encodeWithSignature(sig, delegatee));
    }
}
