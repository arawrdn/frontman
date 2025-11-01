open Vitest

module Tool = Agent__Tool__ReadFile

// Test fixtures are in test/fixtures/
let fixturesPath = "test/fixtures"

describe("Agent__Tool__ReadFile", () => {
  describe("Line-Based Reading", () => {
    testAsync(
      "reads file with correct line numbers",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/normal.txt`, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({content, totalLines, hasMore}) => {
            t->expect(totalLines)->Expect.toBe(30)
            t->expect(hasMore)->Expect.toBe(true)
            t->expect(content->String.includes("00001|"))->Expect.toBe(true)
            t->expect(content->String.includes("00010|"))->Expect.toBe(true)
            t->expect(content->String.includes("00011|"))->Expect.toBe(false)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "respects offset parameter",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/normal.txt`, offset: 5, limit: 5}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({content}) => {
            t->expect(content->String.includes("00006|"))->Expect.toBe(true)
            t->expect(content->String.includes("00005|"))->Expect.toBe(false)
            t->expect(content->String.includes("00010|"))->Expect.toBe(true)
            t->expect(content->String.includes("00011|"))->Expect.toBe(false)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "hasMore is false when reading entire file",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/small.txt`, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({totalLines, hasMore}) => {
            t->expect(totalLines)->Expect.toBe(3)
            t->expect(hasMore)->Expect.toBe(false)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "provides preview field with first ~20 lines",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/normal.txt`, offset: 0, limit: 50}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({preview}) => {
            t->expect(String.length(preview) > 0)->Expect.toBe(true)
            t->expect(preview->String.includes("Line 1:"))->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "truncates very long lines at 2000 chars",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/long-lines.txt`, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({content}) => {
            t->expect(content->String.includes("..."))->Expect.toBe(true)
            t->expect(content->String.includes("Short line"))->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "handles empty file gracefully",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/empty.txt`, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({totalLines, hasMore, content}) => {
            t->expect(totalLines)->Expect.toBe(1) // Empty file has 1 empty line from split
            t->expect(hasMore)->Expect.toBe(false)
            t->expect(content->String.includes("<file>"))->Expect.toBe(true)
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )
  })

  describe("Error Handling", () => {
    testAsync(
      "returns error when offset beyond file length",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/small.txt`, offset: 999, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Error(msg) => t->expect(msg->String.includes("beyond"))->Expect.toBe(true)
        | Ok(_) => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    testAsync(
      "returns error for directory paths",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: fixturesPath, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Error(msg) => t->expect(msg->String.includes("directory"))->Expect.toBe(true)
        | Ok(_) => t->expect(false)->Expect.toBe(true)
        }
      },
    )

    testAsync(
      "returns error for non-existent file",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {
          Tool.path: `${fixturesPath}/does-not-exist.txt`,
          offset: 0,
          limit: 10,
        }

        let result = await Tool.execute(ctx, input)

        switch result {
        | Error(msg) => t->expect(msg->String.includes("not found"))->Expect.toBe(true)
        | Ok(_) => t->expect(false)->Expect.toBe(true)
        }
      },
    )
  })

  describe("Path Resolution", () => {
    testAsync(
      "handles relative paths",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let input = {Tool.path: `${fixturesPath}/small.txt`, offset: 0, limit: 10}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok({totalLines}) => t->expect(totalLines)->Expect.toBe(3)
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )
  })
})
