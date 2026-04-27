import {CodeSandbox, VMTier} from "@codesandbox/sdk"

const tierName = process.env.CSB_VM_TIER ?? "Micro"
const templateId = process.env.CSB_TEMPLATE_ID ?? "codesandbox-frontman-template@frontman-dogfood-micro"
const branch = process.env.FRONTMAN_BRANCH ?? "sandboxing_v2"
const githubToken = process.env.GITHUB_TOKEN
const runDeps = process.env.FRONTMAN_RUN_DEPS === "1"
const vmTier = VMTier[tierName]

if (vmTier === undefined) {
  throw new Error(`Unknown CSB_VM_TIER: ${tierName}`)
}

if (!githubToken) {
  throw new Error("GITHUB_TOKEN is required")
}

const sdk = new CodeSandbox()
let sandbox = null

const trimOutput = output => {
  const maxLength = 12000
  return output.length > maxLength ? `${output.slice(0, 6000)}\n...[truncated]...\n${output.slice(-6000)}` : output
}

const run = async (client, name, command, opts = {}) => {
  const timeoutMs = opts.timeoutMs ?? 120000
  process.stderr.write(`running ${name}\n`)

  try {
    const output = await Promise.race([
      client.commands.run(command, {
        cwd: opts.cwd,
        env: opts.env,
        name,
      }),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs),
      ),
    ])

    return {name, command, ok: true, output: trimOutput(output)}
  } catch (error) {
    return {
      name,
      command,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      output: typeof error?.output === "string" ? trimOutput(error.output) : undefined,
    }
  }
}

const deleteWithRetry = async sandboxId => {
  const attempts = []

  for (let index = 0; index < 3; index += 1) {
    try {
      await sdk.sandboxes.delete(sandboxId)
      attempts.push({attempt: index + 1, ok: true})
      return {destroyed: true, attempts}
    } catch (error) {
      attempts.push({
        attempt: index + 1,
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      })
      await new Promise(resolve => setTimeout(resolve, 2000))
    }
  }

  return {destroyed: false, attempts}
}

const result = {
  provider: "codesandbox",
  experiment: "frontman-clone-and-toolchain-setup",
  templateId,
  sandboxId: null,
  vmTier: tierName,
  branch,
  checks: [],
  cleanup: null,
}

try {
  process.stderr.write(`creating ${tierName} sandbox from ${templateId}\n`)
  sandbox = await sdk.sandboxes.create({
    id: templateId,
    title: `frontman-codesandbox-setup-${Date.now()}`,
    privacy: "private",
    vmTier,
    hibernationTimeoutSeconds: 300,
    automaticWakeupConfig: {
      http: false,
      websocket: false,
    },
  })
  result.sandboxId = sandbox.id
  process.stderr.write(`created ${sandbox.id}\n`)

  const client = await sandbox.connect()
  process.stderr.write(`connected ${sandbox.id}\n`)

  const cloneResult = await run(
    client,
    "clone-frontman",
    `rm -rf frontman && cat > /tmp/frontman-git-askpass <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) echo x-access-token ;;
  *Password*) echo "$GITHUB_TOKEN" ;;
  *) echo "" ;;
esac
EOF
chmod 700 /tmp/frontman-git-askpass && GIT_ASKPASS=/tmp/frontman-git-askpass GIT_TERMINAL_PROMPT=0 git clone --single-branch --branch ${branch} --filter=blob:none https://github.com/frontman-ai/frontman.git frontman && rm -f /tmp/frontman-git-askpass`,
    {env: {GITHUB_TOKEN: githubToken}, timeoutMs: 900000},
  )
  result.checks.push(cloneResult)

  if (!cloneResult.ok) {
    throw new Error("clone-frontman failed")
  }

  const gitStateResult = await run(client, "git-state", "git status --short --branch && git rev-parse HEAD && git remote -v", {
      cwd: "frontman",
    })
  result.checks.push(gitStateResult)

  if (!gitStateResult.ok) {
    throw new Error("git-state failed")
  }
  result.checks.push(await run(client, "mise-install", "mise trust --all && mise install --yes", {cwd: "frontman", timeoutMs: 1200000}))
  result.checks.push(
    await run(
      client,
      "tool-versions",
      "mise exec -- node --version && mise exec -- yarn --version && mise exec -- elixir --version && mise exec -- erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell && mise exec -- mprocs --version",
      {cwd: "frontman", timeoutMs: 120000},
    ),
  )
  result.checks.push(await run(client, "resource-after-mise", "df -h /project/workspace && free -h", {cwd: "frontman"}))

  if (runDeps) {
    result.checks.push(await run(client, "postgres-compose-up", "docker compose up -d db", {timeoutMs: 180000}))
    result.checks.push(
      await run(
        client,
        "postgres-ready",
        "for i in $(seq 1 30); do pg_isready -h localhost -U postgres && exit 0; sleep 2; done; exit 1",
        {timeoutMs: 90000},
      ),
    )
    result.checks.push(await run(client, "yarn-install", "mise exec -- yarn install", {cwd: "frontman", timeoutMs: 1200000}))
    result.checks.push(await run(client, "rescript-build", "mise exec -- yarn rescript build", {cwd: "frontman", timeoutMs: 600000}))
    result.checks.push(
      await run(
        client,
        "mix-deps-and-migrate",
        "mise exec -- bash -lc 'cd apps/frontman_server && mix local.hex --force && mix local.rebar --force && mix deps.get && mix ecto.create || true && mix ecto.migrate'",
        {cwd: "frontman", timeoutMs: 1200000},
      ),
    )
    result.checks.push(await run(client, "resource-after-deps", "df -h /project/workspace && free -h", {cwd: "frontman"}))
  }
} finally {
  if (sandbox !== null) {
    process.stderr.write(`deleting ${sandbox.id}\n`)
    result.cleanup = await deleteWithRetry(sandbox.id)
  }

  console.log(JSON.stringify(result, null, 2))
  process.exit(result.cleanup?.destroyed === false ? 1 : 0)
}
