import { HELLO_WORLD } from "./lib";
import chai from "chai";

try {
  chai.expect(HELLO_WORLD).to.equal("Goodbye, world!");
} catch (err) {
  console.log("Caught an err!");
}
