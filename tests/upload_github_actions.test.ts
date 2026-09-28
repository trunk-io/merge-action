/** Test upload_impacted_targets_github_actions.sh against a stub `trunk` that records its argv. */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";

const SCRIPT = path.resolve("src/scripts/upload_impacted_targets_github_actions.sh");

const BASE_ENV = {
  TARGET_BRANCH: "main",
  PR_NUMBER: "123",
  PR_SHA: "9c58bf40e5c1a2b3d4e5f60718293a4b5c6d7e8f",
  IMPACTS_ALL_DETECTED: "false",
};

describe("upload_impacted_targets_github_actions", () => {
  let dir: string;
  let argvFile: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "upload-gha-"));
    argvFile = path.join(dir, "argv");
    const stub = path.join(dir, "trunk");
    fs.writeFileSync(stub, `#!/usr/bin/env bash\nprintf '%s\\n' "$@" > "${argvFile}"\n`);
    fs.chmodSync(stub, 0o755);
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  const run = (env: Record<string, string>) =>
    execFileSync("bash", [SCRIPT], {
      env: { PATH: `${dir}:${process.env.PATH}`, ...env },
      encoding: "utf8",
      stdio: "pipe",
    });

  const targetsFile = (content: string) => {
    const file = path.join(dir, "targets");
    fs.writeFileSync(file, content);
    return file;
  };

  const argv = () => fs.readFileSync(argvFile, "utf8").trimEnd().split("\n");

  const BASE_ARGS = [
    "mergequeue",
    "upload-impacted-targets",
    "--target-branch",
    "main",
    "--pr",
    "123",
    "--sha",
    "9c58bf40e5c1a2b3d4e5f60718293a4b5c6d7e8f",
  ];

  it("uploads the computed targets file", () => {
    const file = targetsFile("//a:b\n//c:d\n");
    run({ ...BASE_ENV, IMPACTED_TARGETS_FILE: file });
    expect(argv()).toEqual([...BASE_ARGS, "--targets-file", file]);
  });

  it("declares every target impacted when impacts-all was detected", () => {
    run({ ...BASE_ENV, IMPACTS_ALL_DETECTED: "true", IMPACTED_TARGETS_FILE: "" });
    expect(argv()).toEqual([...BASE_ARGS, "--all"]);
  });

  it("declares nothing impacted when the computation found no targets", () => {
    run({ ...BASE_ENV, IMPACTED_TARGETS_FILE: targetsFile("\n  \n") });
    expect(argv()).toEqual([...BASE_ARGS, "--none"]);
  });

  // A missing file is a failed computation; "impacts nothing" would satisfy the readiness gate.
  it("fails without calling trunk when no targets file was computed", () => {
    for (const IMPACTED_TARGETS_FILE of ["", path.join(dir, "missing")]) {
      expect(() => run({ ...BASE_ENV, IMPACTED_TARGETS_FILE })).toThrow();
    }
    expect(fs.existsSync(argvFile)).toBe(false);
  });

  it("fails without calling trunk when a required value is missing", () => {
    for (const missing of Object.keys(BASE_ENV)) {
      const env: Record<string, string> = {
        ...BASE_ENV,
        IMPACTED_TARGETS_FILE: targetsFile("//a:b\n"),
      };
      delete env[missing];
      expect(() => run(env)).toThrow();
    }
    expect(fs.existsSync(argvFile)).toBe(false);
  });

  it("fails when the upload fails", () => {
    fs.writeFileSync(path.join(dir, "trunk"), "#!/usr/bin/env bash\nexit 3\n");
    expect(() => run({ ...BASE_ENV, IMPACTED_TARGETS_FILE: targetsFile("//a:b\n") })).toThrow();
  });
});
