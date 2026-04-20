open Vitest

afterEach(_t => {
  try {
    WebAPI.Global.sessionStorage->WebAPI.Storage.clear
  } catch {
  | _ => ()
  }
})

describe("Client__AuthSessionToken", () => {
  test("stores and retrieves tokens per auth bridge origin", t => {
    Client__AuthSessionToken.set(
      ~originUrl="https://frontman.local:4000/auth-bridge",
      ~token="token-123",
    )

    t
    ->expect(Client__AuthSessionToken.get("https://frontman.local:4000/auth-bridge"))
    ->Expect.toBe(Some("token-123"))
    t
    ->expect(Client__AuthSessionToken.get("https://api.frontman.sh/auth-bridge"))
    ->Expect.toBe(None)
  })

  test("clear removes cached tokens", t => {
    Client__AuthSessionToken.set(
      ~originUrl="https://frontman.local:4000/auth-bridge",
      ~token="token-123",
    )

    Client__AuthSessionToken.clear("https://frontman.local:4000/auth-bridge")

    t
    ->expect(Client__AuthSessionToken.get("https://frontman.local:4000/auth-bridge"))
    ->Expect.toBe(None)
  })
})
