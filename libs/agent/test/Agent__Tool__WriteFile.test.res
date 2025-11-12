open Vitest

module Tool = Agent__Tool__WriteFile
module Bindings = AskTheLlmBindings

// Test fixtures are in test/fixtures/
let fixturesPath = "test/fixtures"

describe("Agent__Tool__WriteFile", () => {
  describe("Directory Creation", () => {
    testAsync(
      "creates nested directories when they don't exist",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let testPath = `${fixturesPath}/write-test/nested/deep/test-file.txt`
        let input = {Tool.relativePath: testPath, content: "Hello, World!"}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok(_) => {
            // Verify the file was created by reading it back
            let fullPath = Bindings.Path.join([ctx.projectRoot, testPath])
            let content = await Bindings.Fs.Promises.readFile(fullPath)
            t->expect(content)->Expect.toBe("Hello, World!")

            // Clean up - remove the test file and directories
            let _ = await %raw(`async function(path) {
              const fs = require('fs').promises;
              const filePath = require('path');
              await fs.unlink(path);
              // Remove nested directories
              await fs.rmdir(filePath.dirname(path));
              await fs.rmdir(filePath.dirname(filePath.dirname(path)));
              await fs.rmdir(filePath.dirname(filePath.dirname(filePath.dirname(path))));
            }`)(fullPath)
            ()
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "writes to existing directory without error",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let testPath = `${fixturesPath}/existing-write-test.txt`
        let input = {Tool.relativePath: testPath, content: "Test content"}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok(_) => {
            // Verify the file was created
            let fullPath = Bindings.Path.join([ctx.projectRoot, testPath])
            let content = await Bindings.Fs.Promises.readFile(fullPath)
            t->expect(content)->Expect.toBe("Test content")

            // Clean up
            let _ = await %raw(`async function(path) {
              const fs = require('fs').promises;
              await fs.unlink(path);
            }`)(fullPath)
            ()
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "overwrites existing file",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let testPath = `${fixturesPath}/overwrite-test.txt`
        
        // First write
        let input1 = {Tool.relativePath: testPath, content: "Original content"}
        let _ = await Tool.execute(ctx, input1)

        // Second write (overwrite)
        let input2 = {Tool.relativePath: testPath, content: "New content"}
        let result = await Tool.execute(ctx, input2)

        switch result {
        | Ok(_) => {
            // Verify the file was overwritten
            let fullPath = Bindings.Path.join([ctx.projectRoot, testPath])
            let content = await Bindings.Fs.Promises.readFile(fullPath)
            t->expect(content)->Expect.toBe("New content")

            // Clean up
            let _ = await %raw(`async function(path) {
              const fs = require('fs').promises;
              await fs.unlink(path);
            }`)(fullPath)
            ()
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )
  })

  describe("Content Writing", () => {
    testAsync(
      "writes multi-line content correctly",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let testPath = `${fixturesPath}/multiline-test.txt`
        let multilineContent = "Line 1\nLine 2\nLine 3"
        let input = {Tool.relativePath: testPath, content: multilineContent}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok(_) => {
            let fullPath = Bindings.Path.join([ctx.projectRoot, testPath])
            let content = await Bindings.Fs.Promises.readFile(fullPath)
            t->expect(content)->Expect.toBe(multilineContent)

            // Clean up
            let _ = await %raw(`async function(path) {
              const fs = require('fs').promises;
              await fs.unlink(path);
            }`)(fullPath)
            ()
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )

    testAsync(
      "writes empty content",
      async t => {
        let ctx = {Agent__ToolExecutionContext.projectRoot: "."}
        let testPath = `${fixturesPath}/empty-content-test.txt`
        let input = {Tool.relativePath: testPath, content: ""}

        let result = await Tool.execute(ctx, input)

        switch result {
        | Ok(_) => {
            let fullPath = Bindings.Path.join([ctx.projectRoot, testPath])
            let content = await Bindings.Fs.Promises.readFile(fullPath)
            t->expect(content)->Expect.toBe("")

            // Clean up
            let _ = await %raw(`async function(path) {
              const fs = require('fs').promises;
              await fs.unlink(path);
            }`)(fullPath)
            ()
          }
        | Error(msg) => {
            Console.error(`Test failed: ${msg}`)
            t->expect(false)->Expect.toBe(true)
          }
        }
      },
    )
  })
})

