import {execFileSync} from "node:child_process"
import {fileURLToPath} from "node:url"
import path from "node:path"
import {Daytona, Image} from "@daytona/sdk"

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, "../..")

const redactUrl = url => {
  try {
    const parsed = new URL(url)
    parsed.hostname = parsed.hostname.replace(/^[^.]+/, "[redacted]")
    return parsed.toString()
  } catch {
    return "[unparseable-url]"
  }
}

const localBranch = () => {
  try {
    const branch = execFileSync("git", ["branch", "--show-current"], {
      cwd: repoRoot,
      encoding: "utf8",
    }).trim()
    return branch === "" ? "main" : branch
  } catch {
    return "main"
  }
}

const parseArgs = argv => {
  const parsed = {
    repo: process.env.FRONTMAN_REPO_URL ?? "https://github.com/frontman-ai/frontman.git",
    branch: process.env.FRONTMAN_BRANCH ?? localBranch(),
    port: Number.parseInt(process.env.DAYTONA_MARKETING_PORT ?? "4321", 10),
    cpu: Number.parseInt(process.env.DAYTONA_CPU ?? "4", 10),
    memory: Number.parseInt(process.env.DAYTONA_MEMORY_GIB ?? "8", 10),
    disk: Number.parseInt(process.env.DAYTONA_DISK_GIB ?? "10", 10),
    ttlSeconds: Number.parseInt(process.env.DAYTONA_PREVIEW_TTL_SECONDS ?? "3600", 10),
    autoStopMinutes: Number.parseInt(process.env.DAYTONA_AUTO_STOP_MINUTES ?? "30", 10),
    keep: true,
    help: false,
  }

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    switch (arg) {
      case "--help":
      case "-h":
        parsed.help = true
        break
      case "--repo":
        parsed.repo = argv[++index]
        break
      case "--branch":
        parsed.branch = argv[++index]
        break
      case "--port":
        parsed.port = Number.parseInt(argv[++index], 10)
        break
      case "--delete":
        parsed.keep = false
        break
      case "--keep":
        parsed.keep = true
        break
      default:
        throw new Error(`Unknown argument: ${arg}`)
    }
  }

  return parsed
}

const usage = () => `Usage: DAYTONA_API_KEY=... node scripts/spikes/daytona-marketing-preview.mjs [options]

Options:
  --repo <url>       Git repository URL. Defaults to FRONTMAN_REPO_URL or GitHub HTTPS.
  --branch <name>    Branch to clone. Defaults to FRONTMAN_BRANCH or the local branch.
  --port <number>    Marketing dev server port. Defaults to 4321.
  --keep             Keep the sandbox running for manual verification. Default.
  --delete           Delete the sandbox after probing the preview URL.

Optional env:
  GITHUB_TOKEN       Token for cloning private repos over HTTPS.
  DAYTONA_CPU        CPU cores. Default: 4.
  DAYTONA_MEMORY_GIB Memory in GiB. Default: 8.
  DAYTONA_DISK_GIB   Disk in GiB. Default: 10.
`

const assertOk = (label, response) => {
  if (response.exitCode !== 0) {
    throw new Error(`${label} failed with exit ${response.exitCode}\n${response.result}`)
  }
}

const runStep = async (sandbox, label, command, cwd, timeoutSeconds) => {
  console.log(`\n[${label}] ${command}`)
  const response = await sandbox.process.executeCommand(command, cwd, undefined, timeoutSeconds)
  process.stdout.write(response.result ?? "")
  assertOk(label, response)
  return response
}

const waitForPreview = async url => {
  const paths = ["/", "/docs/", "/frontman/tools"]
  const results = []

  for (let attempt = 1; attempt <= 30; attempt += 1) {
    results.length = 0

    for (const pathname of paths) {
      const target = new URL(pathname, url).toString()
      try {
        const response = await fetch(target, {redirect: "manual"})
        results.push({path: pathname, status: response.status})
      } catch (error) {
        results.push({
          path: pathname,
          error: error instanceof Error ? error.message : String(error),
        })
      }
    }

    if (results.every(result => result.status !== undefined && result.status < 500)) {
      return results
    }

    await new Promise(resolve => setTimeout(resolve, 2000))
  }

  throw new Error(`Preview did not become healthy: ${JSON.stringify(results)}`)
}

const patchAstroAllowedHostsScript =
  'import fs from "node:fs";' +
  'const file = "apps/marketing/astro.config.mjs";' +
  'const source = fs.readFileSync(file, "utf8");' +
  'const next = source.replace(/allowedHosts: \\[[^\\]]*\\]/, "allowedHosts: true");' +
  'if (next === source) throw new Error("Could not patch Vite allowedHosts");' +
  'fs.writeFileSync(file, next);'
const patchAstroAllowedHostsCommand = `node --input-type=module -e ${JSON.stringify(
  patchAstroAllowedHostsScript,
)}`

const args = parseArgs(process.argv.slice(2))

if (args.help) {
  console.log(usage())
  process.exit(0)
}
const API_KEY = "dtn_b5d059ad596b9f5cdaf9804bc93063817d4952943ac29528f07c5f987f9212a6"

if (!API_KEY) {
  throw new Error("API_KEY is required")
}

if (!Number.isInteger(args.port) || args.port <= 0) {
  throw new Error(`Invalid port: ${args.port}`)
}

const daytona = new Daytona({apiKey: API_KEY})
let sandbox = null
let devCommandId = null
let succeeded = false
const sessionId = `frontman-marketing-${Date.now()}`

const result = {
  provider: "daytona",
  experiment: "marketing-preview",
  repo: args.repo,
  branch: args.branch,
  sandboxId: null,
  resources: {cpu: args.cpu, memory: args.memory, disk: args.disk},
  sessionId,
  devCommandId: null,
  previewUrl: null,
  previewUrlRedacted: null,
  probes: null,
  cleanup: null,
}

try {
  sandbox = await daytona.create(
    {
      image: Image.base("node:24-bookworm").runCommands(
        "apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*",
      ),
      resources: {cpu: args.cpu, memory: args.memory, disk: args.disk},
      autoStopInterval: args.autoStopMinutes,
      autoDeleteInterval: args.keep ? -1 : 0,
      labels: {project: "frontman", experiment: "marketing-preview"},
    },
    {timeout: 300},
  )
  result.sandboxId = sandbox.id

  console.log(`[sandbox] ${sandbox.id}`)
  await sandbox.git.clone(
    args.repo,
    "workspace/frontman",
    args.branch,
    undefined,
    process.env.GITHUB_TOKEN ? "x-access-token" : undefined,
    process.env.GITHUB_TOKEN,
  )

  const workdir = "workspace/frontman"
  await runStep(sandbox, "versions", "node --version && corepack --version && git --version", workdir, 60)
  await runStep(sandbox, "patch allowed hosts", patchAstroAllowedHostsCommand, workdir, 30)
  await runStep(
    sandbox,
    "install",
    "COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn install --immutable",
    workdir,
    900,
  )
  await runStep(
    sandbox,
    "build astro integration",
    "COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn workspace @frontman-ai/astro build",
    workdir,
    600,
  )

  await sandbox.process.createSession(sessionId)
  const devResponse = await sandbox.process.executeSessionCommand(
    sessionId,
    {
      command: `cd ${workdir} && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn workspace marketing dev --host 0.0.0.0 --port ${args.port}`,
      runAsync: true,
    },
    30,
  )
  devCommandId = devResponse.cmdId
  result.devCommandId = devCommandId

  const signedPreview = await sandbox.getSignedPreviewUrl(args.port, args.ttlSeconds)
  result.previewUrl = signedPreview.url
  result.previewUrlRedacted = redactUrl(signedPreview.url)
  result.probes = await waitForPreview(signedPreview.url)
  succeeded = true
} finally {
  if (sandbox !== null && (!args.keep || !succeeded)) {
    try {
      await sandbox.delete(120)
      result.cleanup = {deleted: true}
    } catch (error) {
      result.cleanup = {
        deleted: false,
        error: error instanceof Error ? error.message : String(error),
      }
    }
  } else if (sandbox !== null) {
    result.cleanup = {
      deleted: false,
      reason: "kept for manual verification",
      autoStopMinutes: args.autoStopMinutes,
    }
  }

  console.log("\n[result]")
  console.log(JSON.stringify(result, null, 2))
}
