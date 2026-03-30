// Ultra-resilient growth bot for stx-utils

console.log("🚀 stx-utils Growth Bot Starting...");

let stx;

try {
  stx = require("@yusufolosun/stx-utils");
  console.log("✅ Package loaded");
} catch (err) {
  console.log("⚠️ Package load failed:", err.message);
}

// Safe execution block
try {
  // Formatting
  console.log("formatSTX:", stx?.formatSTX?.(1_500_000) ?? "fallback");

  // Address
  console.log(
    "shorten:",
    stx?.shortenAddress?.(
      "SP1N3809W9CBWWX04KN3TCQHP8A9GN520BD4JMP8Z"
    ) ?? "fallback"
  );

  // Validation
  console.log("isValid:", stx?.isValidAddress?.("SP123") ?? "fallback");

  // Blocks
  console.log("blocksToTime:", stx?.blocksToTime?.(144) ?? "fallback");

  // Explorer
  console.log("txUrl:", stx?.txUrl?.("0xabc123") ?? "fallback");

} catch (err) {
  console.log("⚠️ Execution error:", err.message);
}

console.log("✅ Growth Bot Completed");
