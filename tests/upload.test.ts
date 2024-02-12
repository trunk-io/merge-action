/** Test the compute_impacted_targets actions. */
import express from "express";
import { StatusCodes } from "http-status-codes";
import * as _ from "lodash";
import exec from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import util from "node:util";
import { describe, beforeEach, beforeAll, afterAll, it, expect, afterEach } from "@jest/globals";
import { strict as assert } from "node:assert";

const PORT = 4567;

type ImpactedTargets = string[] | "ALL";

type EnvVar =
  | "API_TOKEN"
  | "REPOSITORY"
  | "TARGET_BRANCH"
  | "PR_NUMBER"
  | "PR_SHA"
  | "IMPACTED_TARGETS_FILE"
  | "IMPACTS_ALL_DETECTED"
  | "API_URL"
  | "RUN_ID"
  | "IS_FORK";

type EnvVarSet = Record<EnvVar, string>;

const fetchUrl = (path: string) => `http://localhost:${PORT}${path}`;
const UPLOAD_IMPACTED_TARGETS_SCRIPT = "src/scripts/upload_impacted_targets.sh";
const DEFAULT_ENV_VARIABLES: EnvVarSet = {
  API_TOKEN: "test-api-token",
  REPOSITORY: "test-repo-owner/test-repo-name",
  TARGET_BRANCH: "test-target-branch",
  PR_NUMBER: "123",
  PR_SHA: "test-pr-sha",
  IMPACTED_TARGETS_FILE: "/tmp/test-impacted-targets-file",
  IMPACTS_ALL_DETECTED: "false",
  API_URL: fetchUrl("/testUploadImpactedTargets"),
  RUN_ID: "123456",
  IS_FORK: "false",
};

describe("upload_impacted_targets", () => {
  let server: http.Server;
  let uploadedImpactedTargetsPayload: {
    apiTokenHeader: string | null;
    forkedWorkflowIdHeader: string | null;
    requestBody: typeof express.request | null;
  } | null = null;
  let exportedEnvVars: EnvVarSet | null = null;
  let forceUnauthorized = false;

  const exportEnv = (env: EnvVarSet): string => {
    exportedEnvVars = env;
    return Object.entries(env)
      .map(([key, value]) => `${key}=${value}`)
      .join(" ");
  };

  const runUploadTargets = async (
    impactedTargets: ImpactedTargets,
    envOverrides: Partial<EnvVarSet> = {},
  ) => {
    const env: EnvVarSet = { ...DEFAULT_ENV_VARIABLES, ...envOverrides };
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
    assert(exportedEnvVars);
    assert(uploadedImpactedTargetsPayload);

    const { API_TOKEN, REPOSITORY, TARGET_BRANCH, PR_NUMBER, PR_SHA, RUN_ID } = exportedEnvVars;
    const { apiTokenHeader, forkedWorkflowIdHeader, requestBody } = uploadedImpactedTargetsPayload;

    expect(apiTokenHeader).toEqual(API_TOKEN);
    expect(forkedWorkflowIdHeader).toEqual(RUN_ID);
    expect(requestBody).toEqual({
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
      const actualRunId = req.headers["x-forked-workflow-run-id"];

      uploadedImpactedTargetsPayload = {
        apiTokenHeader: (actualApiToken ?? "") as string,
        forkedWorkflowIdHeader: (actualRunId ?? "") as string,
        requestBody: req.body,
      };

      assert(exportedEnvVars);
      res.sendStatus(forceUnauthorized ? StatusCodes.UNAUTHORIZED : StatusCodes.OK);
    });

    server = app.listen(PORT);
  });

  beforeEach(function () {
    uploadedImpactedTargetsPayload = null;
    exportedEnvVars = null;
    forceUnauthorized = false;
  });

  afterEach(function () {
    fs.rmSync(DEFAULT_ENV_VARIABLES.IMPACTED_TARGETS_FILE, { force: true });
  });

  afterAll(function () {
    server.close();
  });

  it("rejects if missing required input", async function () {
    await expect(() =>
      util.promisify(exec.exec)(`${UPLOAD_IMPACTED_TARGETS_SCRIPT}`),
    ).rejects.toBeTruthy();
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
    const impactedTargets = [...new Array(1_000)].map((_, i) => `target-${i}`);
    await runUploadTargets(impactedTargets);
    expectImpactedTargetsUpload(impactedTargets);
  });

  it("supports 100K targets", async function () {
    const impactedTargets = [...new Array(100_000)].map((_, i) => `target-${i}`);
    await runUploadTargets(impactedTargets);
    expectImpactedTargetsUpload(impactedTargets);
  });

  it("supports IMPACTS_ALL", async function () {
    await runUploadTargets("ALL", { IMPACTS_ALL_DETECTED: "true" });
    expectImpactedTargetsUpload("ALL");
  });

  it("allows missing API token if PR is coming from a fork", async function () {
    const impactedTargets = ["target-1", "target-2", "target-3"];
    await runUploadTargets(impactedTargets, { API_TOKEN: "", IS_FORK: "true" });
    expectImpactedTargetsUpload(impactedTargets);
  });

  it("rejects when missing API token and is not a fork", async function () {
    await expect(runUploadTargets(["a"], { API_TOKEN: "" })).rejects.toBeTruthy();
  });

  it("rejects when missing forked workflow ID and is not a fork", async function () {
    await expect(
      runUploadTargets(["a"], { API_TOKEN: "", RUN_ID: "", IS_FORK: "true" }),
    ).rejects.toBeTruthy();
  });

  it("rejects on http 401", async function () {
    forceUnauthorized = true;
    await expect(runUploadTargets([])).rejects.toBeTruthy();
  });
});
