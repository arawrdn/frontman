# Agent Test Fixtures

This directory contains committed test fixtures representing different project types for agent integration testing.

## Available Fixtures

### sample-react-component/
A minimal React component (Button) for testing basic file operations:
- Reading TypeScript/React files
- Modifying component code
- Handling JSX syntax
- Working with TypeScript types

## Adding New Fixtures

When creating new fixtures:

1. **Keep them minimal** - Only include files necessary for the test scenario
2. **Make them realistic** - Include package.json, tsconfig.json, etc.
3. **Document the purpose** - Add a README.md explaining what the fixture tests
4. **Commit to git** - Fixtures are part of the repository, not generated
5. **Use meaningful names** - Choose names that describe the test scenario

## Fixture Characteristics

All fixtures should:
- Be small and focused (not full applications)
- Include realistic configuration files
- Have clear documentation
- Represent specific testing scenarios
- Be committed to version control

## Usage in Tests

```rescript
// Get fixture path
let fixtureDir = TestHelpers.getFixturePath("sample-react-component")

// Spawn agent with fixture
let agent = TestHelpers.spawnAgent(fixtureDir)

// Run tests against fixture files
```
