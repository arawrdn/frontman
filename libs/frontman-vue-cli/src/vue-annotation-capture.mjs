// vue-annotation-capture.mjs
// Runs in the browser, injected via webpack EntryPlugin
// Bridges Vue 2's __vue__ component instances to window.__frontman_annotations__

if (typeof window !== 'undefined') {
  const safeSerialize = (props) => {
    if (!props || typeof props !== 'object') return undefined
    const result = {}
    for (const [key, value] of Object.entries(props)) {
      // Filter out non-serializable values
      if (typeof value === 'function' || typeof value === 'symbol') continue
      if (value instanceof HTMLElement) continue
      try {
        JSON.stringify(value) // test serializability
        result[key] = value
      } catch {
        /* skip non-serializable */
      }
    }
    return Object.keys(result).length > 0 ? result : undefined
  }

  const inferNameFromFile = (file) => {
    if (!file) return undefined
    const match = file.match(/([^/\\]+)\.vue$/)
    return match ? match[1] : undefined
  }

  // Lazy API — reads __vue__ at access time (handles SPA navigation naturally)
  window.__frontman_annotations__ = {
    get(el) {
      const vm = el.__vue__
      if (!vm || !vm.$options.__file) return undefined
      return {
        file: vm.$options.__file,
        loc: '1:1', // Vue 2 doesn't provide line/column; default to file start
        componentProps: safeSerialize(vm.$props),
        displayName:
          vm.$options.name ||
          vm.$options._componentTag ||
          inferNameFromFile(vm.$options.__file),
      }
    },
    has(el) {
      return !!(el.__vue__ && el.__vue__.$options.__file)
    },
    size() {
      // Count is expensive; only needed for debugging
      return document.querySelectorAll('*').length // approximate
    },
  }
}
