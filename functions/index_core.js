/** Assembles index_core from string parts (avoids single huge blob in tooling). */
const parts = [0, 1, 2].map((i) => require("./index_core_part_" + i));
const src = parts.join("");
const moduleWrapper = { exports: {} };
const exp = moduleWrapper.exports;
const fn = new Function("exports", "require", "module", src + "\n;return exports;");
module.exports = fn(exp, require, moduleWrapper);
