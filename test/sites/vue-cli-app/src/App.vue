<template>
  <div id="app">
    <h1>Vue CLI Test App</h1>
    <HelloWorld msg="Welcome to the Frontman Vue CLI integration test" />
  </div>
</template>

<script>
import HelloWorld from './components/HelloWorld.vue'

export default {
  name: 'App',
  components: {
    HelloWorld
  }
}
</script>

<style>
#app {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
