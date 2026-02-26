// index.js — Vue CLI service plugin entry
// Vue CLI loads this automatically when the package is installed.
// Delegates to bundled ReScript output.
const { servicePlugin } = require('./dist/service.js')
module.exports = servicePlugin
