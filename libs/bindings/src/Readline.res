// Minimal binding for Node.js readline module (CLI prompts)

// Raw JS implementation using node:readline.
// When running via `curl | bash`, process.stdin is the pipe, not the terminal.
// We try to open /dev/tty directly to get an interactive input stream, falling
// back to process.stdin for normal terminal invocations.
// Returns null on EOF (Ctrl+D) so callers can distinguish it from empty input (Enter).
// IMPORTANT: resolve(answer) must be called BEFORE rl.close() because
// rl.close() synchronously emits 'close', which would resolve with null
// and silently discard the real answer (a Promise resolves only once).
let question: string => promise<Nullable.t<string>> = %raw(`
  async function(prompt) {
    const fs = await import('node:fs');
    const readline = await import('node:readline');

    // Try /dev/tty first (works in curl|bash), fall back to process.stdin
    let input = process.stdin;
    try {
      const ttyFd = fs.openSync('/dev/tty', 'r');
      input = fs.createReadStream(null, { fd: ttyFd });
    } catch (_) {
      // /dev/tty not available — use process.stdin
    }

    const rl = readline.createInterface({
      input: input,
      output: process.stderr,
      terminal: true,
    });
    return new Promise((resolve) => {
      rl.on('close', () => resolve(null));
      rl.question(prompt, (answer) => {
        resolve(answer);
        rl.close();
      });
    });
  }
`)

// Check if we can prompt interactively.
// In curl|bash scenarios, process.stdin.isTTY is false but /dev/tty may exist.
// We try to actually open /dev/tty — if it opens, there's a real terminal.
// This also handles CI environments where /dev/tty may exist but isn't usable.
let isTTY: unit => bool = %raw(`
  function() {
    if (process.stdin.isTTY) return true;
    // Fallback: try opening /dev/tty (curl|bash with terminal)
    try {
      const fs = require('node:fs');
      const fd = fs.openSync('/dev/tty', 'r');
      fs.closeSync(fd);
      return true;
    } catch (_) {
      return false;
    }
  }
`)
