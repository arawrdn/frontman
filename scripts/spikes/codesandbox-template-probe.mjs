import {CodeSandbox, VMTier} from "@codesandbox/sdk"

const tierName = process.env.CSB_VM_TIER ?? "Micro"
const templateId = process.env.CSB_TEMPLATE_ID ?? "codesandbox-frontman-template@frontman-dogfood-micro"
const vmTier = VMTier[tierName]

if (vmTier === undefined) {
  throw new Error(`Unknown CSB_VM_TIER: ${tierName}`)
}

const sdk = new CodeSandbox()
let sandbox = null

const run = async (client, name, command, timeoutMs = 60000) => {
  process.stderr.write(`running ${name}\n`)

  try {
    const output = await Promise.race([
      client.commands.run(command),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`Timed out after ${timeoutMs}ms`)), timeoutMs),
      ),
    ])

    return {name, command, ok: true, output}
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
  experiment: "micro-template-probe",
  templateId,
  sandboxId: null,
  vmTier: tierName,
  checks: [],
  cleanup: null,
}

try {
  process.stderr.write(`creating ${tierName} sandbox from ${templateId}\n`)
  sandbox = await sdk.sandboxes.create({
    id: templateId,
    title: `frontman-codesandbox-template-${Date.now()}`,
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

  const checks = [
    ["workspace", "pwd && ls -la && ls -la .codesandbox"],
    ["os", "cat /etc/os-release"],
    ["mise", "mise --version"],
    ["node-before-mise", "node --version || true"],
    ["postgres-client", "pg_isready --version"],
    ["docker", "docker --version && docker compose version"],
    ["postgres-compose-up", "docker compose up -d db", 180000],
    ["postgres-ready", "for i in $(seq 1 30); do pg_isready -h localhost -U postgres && exit 0; sleep 2; done; exit 1", 90000],
    ["resources", "df -h /project/workspace && free -h"],
  ]

  for (const [name, command, timeoutMs] of checks) {
    result.checks.push(await run(client, name, command, timeoutMs))
  }
} finally {
  if (sandbox !== null) {
    process.stderr.write(`deleting ${sandbox.id}\n`)
    result.cleanup = await deleteWithRetry(sandbox.id)
  }

  console.log(JSON.stringify(result, null, 2))
  process.exit(result.cleanup?.destroyed === false ? 1 : 0)
}
