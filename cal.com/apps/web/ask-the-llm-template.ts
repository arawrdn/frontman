export const askTheLlmHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ask the LLM</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
            background-color: #f9fafb;
        }
        .container {
            background: white;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
            padding: 32px;
            text-align: center;
        }
        h1 {
            color: #111827;
            margin-bottom: 16px;
        }
        p {
            color: #6b7280;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Ask the LLM</h1>
        <p>Welcome to the Ask the LLM page! This page is now served from a separate HTML template.</p>
        <p>External script functionality will be loaded from the development server.</p>
    </div>
    <script src="http://localhost:5173/ask-the-llm.js"></script>
</body>
</html>`;