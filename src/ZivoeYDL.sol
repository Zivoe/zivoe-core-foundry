// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./OpenZeppelin/OwnableGovernance.sol";

import { IERC20, CRVMultiAssetRewards, IZivoeRET, IZivoeGBL } from "./interfaces/InterfacesAggregated.sol";

/// @dev    This contract is modular and can facilitate distributions of assets held in escrow.
///         Distributions can be made on a preset schedule.
///         Assets can be held in escrow within this contract prior to distribution.
///         Assets can be converted to another asset prior to distribution.
///         Assets can be migrated to OCYLockers prior to distribution.
contract ZivoeYDL is OwnableGovernance {
    
    // E(t) = earnings between t-1 and t
    // This is just what's coming in (the profits, current FRAX bal).

    // P(t) = distributable earnings "payouts"
    // This is FRAX avail after the "fee"/"haricut".

    // r_dao = fraction per unit earnings allocated for DAO/treasury
    // 1/5 = 20% = "haircut fee"
    // on-chain value in basis points
    // GOVERNED (modifiable)
    // (restricted range, [1000, 6000])

    // E_dao = E(t)r_dao = payout at time t for DAO
    // the value of "haircut fee" in FRAX

    // :y = target annual yield for senior
    // in basis points
    // GOVERNED (modifiable)
    // ramifications of upper-bound = overage shrinks if uncapped

    // q = multiple of the senior yield that gives the junior yield
    // scalar
    // GOVERNED

    // r_s(t), r_j(t) are not tracked on-chain
    // = fraction of payout from time t-1 to t that go to
    // senior and junior tranche holders respectively
    
    // Y = target payout per unit time (result of above values)
    // intermediate value

    // P_s(t), P_j(t) = total payout of the junior and senior pools respectively, meet the target
    // intermediate value

    // t = time units since start, genesis of product
    // storing seconds there are (each period is nominal)

    // N = total nominal value of the fund, total supply of both tranche tokens
    // sum(zJTT.supply() + zSTT.supply())
    // avail on-chain already

    // n_s, n_j = supply of senior/junior tranche respectively
    // avail on-chain already

    // m_s, m_j = total staked supply of senior/junior tranche respectively
    // avail on-chain already

    // M = m_s, m_j = total supply that is staked (both junior+senior)
    // avail on-chain already

    // L = total asset units that have been displaced from the pool by loss
    // track this (TODO: figure out globally where to store this variable)

    // ~m_j, ~m_s = adjusted stakes accounting for reduction 
    // in staked hard assets due to loss
    // calculated/intermediate value

    // ---------------
    // State Variables
    // ---------------

    uint256 lastDistributionUnix;
    uint256 distributionInterval;

    address FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address public immutable GBL;    /// @dev The ZivoeGlobals contract.

    address GOV;

    address[] public wallets;

    // -----------
    // Constructor
    // -----------

    /// @notice Initialize the ZivoeYDL.sol contract.
    /// @param gov      Governance contract.
    /// @param _GBL The ZivoeGlobals contract.
    constructor (
        address gov,
        address _GBL
    ) {
        lastDistributionUnix = block.timestamp;
        GBL = _GBL;
        transferOwnershipOnce(gov);
    }
    


    // ---------
    // Functions
    // ---------

    function initialize() public {
        require(wallets[0] == address(0));
        require(IZivoeGBL(GBL).stSTT() != address(0));
        address[] memory _wallets = new address[](4);
        _wallets[0] = IZivoeGBL(GBL).stSTT();
        _wallets[1] = IZivoeGBL(GBL).stJTT();
        _wallets[2] = IZivoeGBL(GBL).stZVE();
        _wallets[3] = IZivoeGBL(GBL).vestZVE();
        _wallets[4] = IZivoeGBL(GBL).RET();
        wallets = _wallets;
    }

    function forwardAssets() public {
        
        uint256[] memory amounts = getDistribution();

        for (uint256 i = 0; i < wallets.length; i++) {
            if (i == 4) {
                IERC20(FRAX).transfer(wallets[i], amounts[i]);
            } 
            else {
                IERC20(FRAX).approve(wallets[i], amounts[i]);
                CRVMultiAssetRewards(wallets[i]).notifyRewardAmount(FRAX, amounts[i]);
            }
        }
    }


    /// @notice Returns an average amount for all wallets.
    function getDistribution() public view returns(uint256[] memory amounts) {
        amounts = new uint256[](wallets.length);
        for (uint256 i = 0; i < wallets.length; i++) {
            amounts[i] = IERC20(FRAX).balanceOf(address(this)) / wallets.length;
        }
    }


    /// @notice Pass through mechanism to accept capital from external actor, specifically to
    ///         forward this to a MultiRewards.sol contract ($ZVE/$zSTT/$zJTT).
    function passThrough(address asset, uint256 amount, address multi) public {
        IERC20(asset).transferFrom(_msgSender(), multi, amount);
        CRVMultiAssetRewards(multi).notifyRewardAmount(asset, amount);
    }

}
