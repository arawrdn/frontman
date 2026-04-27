import {CodeSandbox, VMTier} from "@codesandbox/sdk"

const tierName = process.env.CSB_VM_TIER ?? "Micro"
const vmTier = VMTier[tierName]

if (vmTier === undefined) {
  throw new Error(`Unknown CSB_VM_TIER: ${tierName}`)
}

const sdk = new CodeSandbox()
let sandbox = null

const run = async (client, name, command) => {
  const timeoutMs = 30000
  process.stderr.write(`running ${name}\n`)

  try {
    const output = await Promise.race([
      client.commands.run(command),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs),
      ),
    ])

    return {
      name,
      command,
      ok: true,
      output,
    }
  } catch (error) {
    return {
      name,
      command,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
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
  experiment: "micro-runtime-probe",
  sandboxId: null,
  vmTier: tierName,
  privacy: "private",
  checks: [],
  cleanup: null,
}

try {
  process.stderr.write(`creating ${tierName} sandbox\n`)
  sandbox = await sdk.sandboxes.create({
    title: `frontman-codesandbox-runtime-${Date.now()}`,
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

  process.stderr.write(`connecting ${sandbox.id}\n`)
  const client = await sandbox.connect()
  process.stderr.write(`connected ${sandbox.id}\n`)

  const checks = [
    ["workspace", "pwd && ls -la"],
    ["os", "uname -a && cat /etc/os-release || true"],
    ["user", "whoami && id"],
    ["shells", "command -v bash; command -v zsh || true"],
    ["node", "node --version && npm --version && corepack --version || true"],
    ["git", "git --version"],
    ["sudo", "sudo -n true && echo sudo-ok || echo sudo-unavailable"],
    ["apt", "command -v apt-get && apt-get --version || true"],
    ["docker", "docker --version && docker compose version"],
    ["postgres-client", "command -v pg_isready && pg_isready --version || true"],
    ["resources", "df -h /project/workspace && free -h"],
    ["mise", "command -v mise && mise --version || true"],
  ]

  for (const [name, command] of checks) {
    result.checks.push(await run(client, name, command))
  }
} finally {
  if (sandbox !== null) {
    process.stderr.write(`deleting ${sandbox.id}\n`)
    result.cleanup = await deleteWithRetry(sandbox.id)
  }

  console.log(JSON.stringify(result, null, 2))
  process.exit(result.cleanup?.destroyed === false ? 1 : 0)
}
