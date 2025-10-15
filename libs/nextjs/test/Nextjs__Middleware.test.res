// open RescriptVitest

// describe("Nextjs.Middleware", () => {
//   test("config creates matcher with paths", () => {
//     let cfg = Nextjs.Middleware.config(~paths=["/api/:path*"])

//     // Config should be created successfully
//     expect(cfg)->Vitest.Expect.toBeDefined
//   })

//   test("defaultMiddleware returns a promise", async () => {
//     // Create a mock request
//     let mockRequest = %raw(`{
//       url: "http://localhost:3000/api/test",
//       method: "GET",
//       headers: new Headers()
//     }`)

//     let response = await Nextjs.Middleware.defaultMiddleware(mockRequest)

//     // Should return a response
//     expect(response)->Vitest.Expect.toBeDefined
//   })
// })

