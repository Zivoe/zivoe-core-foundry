// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, IZivoeITO } from "../interfaces/InterfacesAggregated.sol";

contract TrancheLiquidityProvider {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amt) external {
        IERC20(token).transfer(to, amt);
    }

    function view_amountWithdrawableSeniorBurn(address ito, address asset) external returns(uint256) {
        return IZivoeITO(ito).amountWithdrawableSeniorBurn(asset);
    }

    function write_claim(address ito) external returns(uint256, uint256, uint256) {
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

    function try_flipSwitch(address tranches) external returns (bool ok) {
        string memory sig = "flipSwitch()";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig));
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

    function try_getReward(address stk) external returns (bool ok) {
        string memory sig = "getReward()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }
}