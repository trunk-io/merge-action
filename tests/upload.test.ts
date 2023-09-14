/** Test the compute_impacted_targets actions. */
import express from "express";
import { StatusCodes } from "http-status-codes";
import * as _ from "lodash";
import exec from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import util from "node:util";

const PORT = 4567;

type ImpactedTargets = string[] | "ALL";

const fetchUrl = (path: string) => `http://localhost:${PORT}${path}`;
const UPLOAD_IMPACTED_TARGETS_SCRIPT = "src/scripts/upload_impacted_targets.sh";
const ENV_VARIABLES: Record<string, string> = {
  API_TOKEN: "test-api-token",
  REPOSITORY: "test-repo-owner/test-repo-name",
  TARGET_BRANCH: "test-target-branch",
  PR_NUMBER: "123",
  PR_SHA: "test-pr-sha",
  IMPACTED_TARGETS_FILE: "/tmp/test-impacted-targets-file",
  IMPACTS_ALL_DETECTED: "false",
  API_URL: fetchUrl("/testUploadImpactedTargets"),
};
const exportEnv = (env: Record<string, string>) =>
  Object.entries(env)
    .map(([key, value]) => `${key}=${value}`)
    .join(" ");

// assigned in beforeAll
let server: http.Server;

// assigned in beforeEach
let uploadedImpactedTargetsPayload = [null, null];

const runUploadTargets = async (
  impactedTargets: ImpactedTargets,
  env: Record<string, string> = ENV_VARIABLES,
) => {
  // The bazel / glob / ... scripts are responsible for populating these files.
  // Verify that the upload works as intended.
  if (impactedTargets !== "ALL") {
    fs.writeFileSync(env.IMPACTED_TARGETS_FILE, impactedTargets.join("\n"));
  }

  const runScript = util.promisify(exec.exec)(
    `${exportEnv(env)} ${UPLOAD_IMPACTED_TARGETS_SCRIPT}`,
  );

  await runScript;
};

const expectImpactedTargetsUpload = (impactedTargets: ImpactedTargets): void => {
  const { API_TOKEN, REPOSITORY, TARGET_BRANCH, PR_NUMBER, PR_SHA } = ENV_VARIABLES;
  const [actualToken, actualBody] = uploadedImpactedTargetsPayload;
  expect(actualToken).toEqual(API_TOKEN);
  expect(actualBody).toEqual({
    repo: {
      host: "github.com",
      owner: REPOSITORY.split("/")[0],
      name: REPOSITORY.split("/")[1],
    },
    pr: {
      number: PR_NUMBER,
      sha: PR_SHA,
    },
    targetBranch: TARGET_BRANCH,
    impactedTargets,
  });
};

beforeAll(function () {
  const app = express();

  app.use(express.json({ limit: "10mb" }));

  app.post("/testUploadImpactedTargets", (req, res) => {
    const actualApiToken = req.headers["x-api-token"];
    uploadedImpactedTargetsPayload = [actualApiToken, req.body];

    res.sendStatus(
      actualApiToken === ENV_VARIABLES.API_TOKEN ? StatusCodes.OK : StatusCodes.UNAUTHORIZED,
    );
  });

  server = app.listen(PORT);
});

beforeEach(function () {
  uploadedImpactedTargetsPayload = [null, null];
});

afterEach(function () {
  fs.rmSync(ENV_VARIABLES.IMPACTED_TARGETS_FILE, { force: true });
});

afterAll(function () {
  server.close();
});

// Tests

test("rejects if missing required input", async function () {
  await expect(() =>
    util.promisify(exec.exec)(`${UPLOAD_IMPACTED_TARGETS_SCRIPT}`),
  ).rejects.toBeTruthy();
});

test("hits the endpoint", async function () {
  const impactedTargets = ["target-1", "target-2", "target-3"];
  await runUploadTargets(impactedTargets);
  expectImpactedTargetsUpload(impactedTargets);
});

test("supports empty targets", async function () {
  const impactedTargets: string[] = [];
  await runUploadTargets(impactedTargets);
  expectImpactedTargetsUpload(impactedTargets);
});

test("supports 1K targets", async function () {
  const impactedTargets = [...new Array(1_000)].map((_, i) => `target-${i}`);
  await runUploadTargets(impactedTargets);
  expectImpactedTargetsUpload(impactedTargets);
});

test("supports 100K targets", async function () {
  const impactedTargets = [...new Array(100_000)].map((_, i) => `target-${i}`);
  await runUploadTargets(impactedTargets);
  expectImpactedTargetsUpload(impactedTargets);
});

test("supports IMPACTS_ALL", async function () {
  const env = { ...ENV_VARIABLES, IMPACTS_ALL_DETECTED: "true" };
  await runUploadTargets("ALL", env);
  expectImpactedTargetsUpload("ALL");
});

test("rejects when missing API token", async function () {
  await expect(runUploadTargets([], _.omit(ENV_VARIABLES, "API_TOKEN"))).rejects.toBeTruthy();
});

test("rejects on http 401", async function () {
  const malformedEnv = {
    ...ENV_VARIABLES,
    API_TOKEN: " ",
  };
  await expect(runUploadTargets([], malformedEnv)).rejects.toBeTruthy();
});
