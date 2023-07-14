"use strict";

const util = require("node:util");
const exec = util.promisify(require("node:child_process").exec);

describe("addition", function () {
  it("runs a shell script", async function () {
    const { stdout } = await exec("./src/hello_world/mocha_cli/script.sh");
    console.log(stdout);
  });
});
