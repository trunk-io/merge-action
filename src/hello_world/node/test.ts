import { HELLO_WORLD } from "./lib";
import chai from "chai";
import mocha from "mocha";

console.log(mocha);
console.log(mocha.describe);
mocha.describe("", function () {});

// // mocha.describe("TestSuite", function () {
// //     mocha.it("runs a test", function() {
// //         chai.expect(HELLO_WORLD).to.equal("Hello, world!");
// //     });
// // });

// // console.log(HELLO_WORLD);

// if (Module === "main")
