import {CodeSandbox, VMTier} from "@codesandbox/sdk"

const redactUrl = url => {
  try {
    const parsed = new URL(url)
    for (const key of [...parsed.searchParams.keys()]) {
      parsed.searchParams.set(key, "[redacted]")
    }
    return parsed.toString()
  } catch {
    return "[unparseable-url]"
  }
}

const tierName = process.env.CSB_VM_TIER ?? "Micro"
const vmTier = VMTier[tierName]

if (vmTier === undefined) {
  throw new Error(`Unknown CSB_VM_TIER: ${tierName}`)
}

const result = {
  provider: "codesandbox",
  experiment: "minimal-sdk-smoke-test",
  sandboxId: null,
  vmTier: tierName,
  privacy: "private",
  nodeVersion: null,
  port: null,
  previewUrlRedacted: null,
  previewFetchStatus: null,
  destroyed: false,
  deleteError: null,
}

const sdk = new CodeSandbox()
let sandbox = null
let serverCommand = null

try {
  sandbox = await sdk.sandboxes.create({
    title: `frontman-codesandbox-smoke-${Date.now()}`,
    privacy: "private",
    vmTier,
    hibernationTimeoutSeconds: 300,
    automaticWakeupConfig: {
      http: false,
      websocket: false,
    },
  })
  result.sandboxId = sandbox.id

  const hostToken = await sdk.hosts.createToken(sandbox.id, {
    expiresAt: new Date(Date.now() + 60 * 60 * 1000),
  })
  const client = await sandbox.connect()

  result.nodeVersion = (await client.commands.run("node --version")).trim()

  serverCommand = await client.commands.runBackground(
    "node -e \"require('node:http').createServer((req,res)=>{res.end('frontman codesandbox smoke')}).listen(3000,'0.0.0.0')\"",
    {name: "smoke-http-server"},
  )

  const portInfo = await client.ports.waitForPort(3000)
  result.port = {
    port: portInfo.port,
    host: portInfo.host,
  }

  const previewUrl = sdk.hosts.getUrl(hostToken, 3000)
  result.previewUrlRedacted = redactUrl(previewUrl)

  const response = await fetch(previewUrl)
  result.previewFetchStatus = response.status
} finally {
  if (serverCommand !== null) {
    try {
      await serverCommand.kill()
    } catch {}
  }

  if (sandbox !== null) {
    try {
      await sdk.sandboxes.delete(sandbox.id)
      result.destroyed = true
    } catch (error) {
      result.deleteError = error instanceof Error ? error.message : String(error)
    }
  }

  console.log(JSON.stringify(result, null, 2))
  process.exit(result.deleteError === null ? 0 : 1)
}
