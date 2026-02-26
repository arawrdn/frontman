// Vue CLI generator — runs during `vue invoke @frontman-ai/vue-cli`
// Since Vue CLI service plugins are auto-discovered from package.json
// dependencies, the generator's main job is just adding the dependency.
module.exports = (api, options) => {
  api.extendPackage({
    devDependencies: {
      '@frontman-ai/vue-cli': '^0.1.0'
    }
  })
}
