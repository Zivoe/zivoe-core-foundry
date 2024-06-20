import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "abis/generated.ts",
  contracts: [],
  plugins: [
    foundry({
      project: "./",
      artifacts: "out/",
      include: [
        "MockStablecoin.sol/MockStablecoin.json",
        "ZivoeGlobals.sol/ZivoeGlobals.json",
        "ZivoeITO.sol/ZivoeITO.json",
        "ZivoeTrancheToken.sol/ZivoeTrancheToken.json",
        "ZivoeToken.sol/ZivoeToken.json",
        "ZivoeTranches.sol/ZivoeTranches.json",
        "ZivoeRewards.sol/ZivoeRewards.json",
        "ZivoeRewardsVesting.sol/ZivoeRewardsVesting.json",
        "OCC_Modular.sol/OCC_Modular.json",
        "ZivoeGovernorV2.sol/ZivoeGovernorV2.json",
        "ZivoeDAO.sol/ZivoeDAO.json",
        "ZivoeYDL.sol/ZivoeYDL.json",
        "OCR_Modular.sol/OCR_Modular.json",
        "OCL_ZVE.sol/OCL_ZVE.json",
        "OCE_ZVE.sol/OCE_ZVE.json",
      ],
    }),
  ],
});
