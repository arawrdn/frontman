// vue.config.js
// @frontman-ai/vue-cli is auto-discovered as a service plugin
// from devDependencies — no explicit configuration needed.
//
// To pass custom options:
// module.exports = {
//   pluginOptions: {
//     frontman: {
//       host: 'my-server.example.com',
//     }
//   }
// }

const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    allowedHosts: 'all',
  },
})
