<template>
  <div class="hello">
    <h2>{{ msg }}</h2>
    <p class="greeting">Hello from Vue 2! This text can be edited by the AI agent.</p>
    <div class="card">
      <h3>Features</h3>
      <ul>
        <li>Element-to-code detection via __vue__ instances</li>
        <li>Props serialization from $props</li>
        <li>HMR error checking after edits</li>
        <li>Log capture from webpack dev server</li>
      </ul>
    </div>
    <div class="card">
      <h3>How to Test</h3>
      <p>Navigate to <code>/frontman</code> to open the Frontman UI.</p>
      <p>Try asking the agent to change the greeting text above.</p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'HelloWorld',
  props: {
    msg: {
      type: String,
      default: 'Hello World'
    }
  }
}
</script>

<style scoped>
.hello {
  max-width: 600px;
  margin: 0 auto;
}

.greeting {
  font-size: 1.25rem;
  color: #42b883;
  font-weight: 600;
  padding: 12px 24px;
  background: #f0faf5;
  border-radius: 8px;
  border: 2px solid #42b883;
}

.card {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 20px;
  margin: 16px 0;
  text-align: left;
}

.card h3 {
  margin-top: 0;
  color: #35495e;
}

.card ul {
  padding-left: 20px;
}

.card li {
  margin: 8px 0;
  color: #555;
}

code {
  background: #e8e8e8;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.9em;
}
</style>
