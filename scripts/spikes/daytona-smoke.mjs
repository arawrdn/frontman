import {Daytona, Image} from "@daytona/sdk"

const redactUrl = url => {
  try {
    const parsed = new URL(url)
    parsed.hostname = parsed.hostname.replace(/^[^.]+/, "[redacted]")
    return parsed.toString()
  } catch {
    return "[unparseable-url]"
  }
}

if (!process.env.DAYTONA_API_KEY) {
  throw new Error("DAYTONA_API_KEY is required")
}

const cpu = Number.parseInt(process.env.DAYTONA_CPU ?? "2", 10)
const memory = Number.parseInt(process.env.DAYTONA_MEMORY_GIB ?? "4", 10)
const disk = Number.parseInt(process.env.DAYTONA_DISK_GIB ?? "8", 10)
const port = Number.parseInt(process.env.DAYTONA_SMOKE_PORT ?? "3000", 10)
const sessionId = `frontman-daytona-smoke-${Date.now()}`

const daytona = new Daytona()
let sandbox = null

const result = {
  provider: "daytona",
  experiment: "minimal-sdk-smoke-test",
  sandboxId: null,
  resources: {cpu, memory, disk},
  pythonVersion: null,
  sessionId,
  previewUrlRedacted: null,
  previewFetchStatus: null,
  cleanup: null,
}

try {
  sandbox = await daytona.create({
    image: Image.debianSlim("3.12"),
    resources: {cpu, memory, disk},
    ephemeral: true,
    autoStopInterval: 5,
  })
  result.sandboxId = sandbox.id

  const version = await sandbox.process.executeCommand("python3 --version")
  result.pythonVersion = version.result.trim()

  await sandbox.process.createSession(sessionId)
  await sandbox.process.executeSessionCommand(sessionId, {
    command: `python3 -m http.server ${port} --bind 0.0.0.0`,
    runAsync: true,
  })

  await new Promise(resolve => setTimeout(resolve, 3000))
  const signedPreview = await sandbox.getSignedPreviewUrl(port, 3600)
  result.previewUrlRedacted = redactUrl(signedPreview.url)

  const response = await fetch(signedPreview.url)
  result.previewFetchStatus = response.status
} finally {
  if (sandbox !== null) {
    try {
      await sandbox.delete()
      result.cleanup = {destroyed: true}
    } catch (error) {
      result.cleanup = {
        destroyed: false,
        error: error instanceof Error ? error.message : String(error),
      }
    }
  }

  console.log(JSON.stringify(result, null, 2))
  process.exit(result.cleanup?.destroyed === false ? 1 : 0)
}
