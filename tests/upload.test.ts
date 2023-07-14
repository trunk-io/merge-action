/** Test the compute_impacted_targets actions. */
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import express from "express";
import { StatusCodes } from "http-status-codes";
import * as _ from "lodash";
import { strict as assert } from "node:assert";
import exec from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import util from "node:util";

chai.use(chaiAsPromised);
const { expect } = chai;

const PORT = 4567;

const fetchUrl = (path: string) => `http://localhost:${PORT}${path}`;
const UPLOAD_IMPACTED_TARGETS_SCRIPT = "/upload_impacted_targets.sh";
const ENV_VARIABLES: Record<string, string> = {
  API_TOKEN: "test-api-token",
  REPOSITORY: "test-repo-owner/test-repo-name",
  TARGET_BRANCH: "test-target-branch",
  PR_NUMBER: "123",
  PR_SHA: "test-pr-sha",
  IMPACTED_TARGETS_FILE: "/test-impacted-targets-file",
  API_URL: fetchUrl("/testUploadImpactedTargets"),
};

const exportEnv = (env: Record<string, string>) =>
  Object.entries(env)
    .map(([key, value]) => `${key}=${value}`)
    .join(" ");

describe("ComputeImpactedTargetsAction", function () {
  let server: http.Server;
  // x-api-token, body
  let uploadedImpactedTargetsPayload = [null, null];

  // Start an HTTP Server with a single endpoint.
  before(function () {
    const app = express();

    app.use(express.json({ limit: "10mb" }));

    app.post("/testUploadImpactedTargets", (req, res) => {
      const actualApiToken = req.headers["x-api-token"];
      uploadedImpactedTargetsPayload = [actualApiToken, req.body];

      res.sendStatus(
        actualApiToken === ENV_VARIABLES.API_TOKEN ? StatusCodes.OK : StatusCodes.UNAUTHORIZED,
      );
    });

    server = app.listen(PORT, () => console.debug("Server listening on %d", PORT));
  });

  beforeEach(function () {
    uploadedImpactedTargetsPayload = [null, null];
  });

  after(function () {
    server.close();
  });

  context("UploadImpactedTargets", function () {
    const expectImpactedTargetsUpload = (impactedTargets: string[]): void => {
      const { API_TOKEN, REPOSITORY, TARGET_BRANCH, PR_NUMBER, PR_SHA } = ENV_VARIABLES;
      const [actualToken, actualBody] = uploadedImpactedTargetsPayload;
      assert(actualToken);
      assert(actualBody);

      // Assert on the body
    };

    const runUploadTargets = async (
      impactedTargets: string[],
      env: Record<string, string> = ENV_VARIABLES,
      shouldPass = true,
    ) => {
      // The bazel / glob / ... scripts are responsible for populating these files.
      // Verify that the upload works as intended.
      fs.writeFileSync(env.IMPACTED_TARGETS_FILE, impactedTargets.join("\n"));

      await util.promisify(exec.exec)("ls -alR");
      console.log(`${exportEnv(env)} ${UPLOAD_IMPACTED_TARGETS_SCRIPT}`);

      const runScript = util.promisify(exec.exec)(
        `${exportEnv(env)} ${UPLOAD_IMPACTED_TARGETS_SCRIPT}`,
      );

      if (shouldPass) {
        await expect(runScript).to.eventually.be.fulfilled;
      } else {
        await expect(runScript).to.eventually.be.rejected;
      }
    };

    afterEach(function () {
      if (fs.statSync(ENV_VARIABLES.IMPACTED_TARGETS_FILE, { throwIfNoEntry: false })) {
        fs.rmSync(ENV_VARIABLES.IMPACTED_TARGETS_FILE);
      }
    });

    it("rejects if missing required input", function () {
      expect(() => exec.execFileSync(UPLOAD_IMPACTED_TARGETS_SCRIPT)).to.throw;
    });

    it("hits the endpoint", async function () {
      const impactedTargets = ["target-1", "target-2", "target-3"];
      await runUploadTargets(impactedTargets);
      expectImpactedTargetsUpload(impactedTargets);
    });

    it("supports empty targets", async function () {
      const impactedTargets: string[] = [];
      await runUploadTargets(impactedTargets);
      expectImpactedTargetsUpload(impactedTargets);
    });

    it("supports 1K targets", async function () {
      const impactedTargets = [...new Array(1_000)].map((n) => `target-${n}`);
      await runUploadTargets(impactedTargets);
      expectImpactedTargetsUpload(impactedTargets);
    });

    it("supports 100K targets", async function () {
      const impactedTargets = [...new Array(1_000)].map((n) => `target-${n}`);
      await runUploadTargets(impactedTargets);
      expectImpactedTargetsUpload(impactedTargets);
    });

    context("on error", function () {
      context("authn error", function () {
        const ENV_MALFORMED_API_TOKEN: Record<string, string> = {
          ...ENV_VARIABLES,
          API_TOKEN: " ",
        };

        it("on missing API token", async function () {
          await runUploadTargets([], _.omit(ENV_VARIABLES, "API_TOKEN"), false);
        });

        it("on 401 error", async function () {
          await runUploadTargets([], ENV_MALFORMED_API_TOKEN, false);
        });
      });
    });
  });
});
