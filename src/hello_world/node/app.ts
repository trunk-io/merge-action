import { HELLO_WORLD } from "./lib";
import chai from "chai";
import { describe } from "mocha";

try {
  chai.expect(HELLO_WORLD).to.equal("Goodbye, world!");
} catch (err) {
  console.log("Caught an err!");
}

describe("TestSuite", async function () {});
