(function () {
  'use strict';

  // src/vue-annotation-capture.mjs
  if (typeof window !== "undefined") {
    const safeSerialize = (props) => {
      if (!props || typeof props !== "object") return void 0;
      const result = {};
      for (const [key, value] of Object.entries(props)) {
        if (typeof value === "function" || typeof value === "symbol") continue;
        if (value instanceof HTMLElement) continue;
        try {
          JSON.stringify(value);
          result[key] = value;
        } catch (e) {
        }
      }
      return Object.keys(result).length > 0 ? result : void 0;
    };
    const inferNameFromFile = (file) => {
      if (!file) return void 0;
      const match = file.match(/([^/\\]+)\.vue$/);
      return match ? match[1] : void 0;
    };
    window.__frontman_annotations__ = {
      get(el) {
        const vm = el.__vue__;
        if (!vm || !vm.$options.__file) return void 0;
        return {
          file: vm.$options.__file,
          loc: "1:1",
          // Vue 2 doesn't provide line/column; default to file start
          componentProps: safeSerialize(vm.$props),
          displayName: vm.$options.name || vm.$options._componentTag || inferNameFromFile(vm.$options.__file)
        };
      },
      has(el) {
        return !!(el.__vue__ && el.__vue__.$options.__file);
      },
      size() {
        return document.querySelectorAll("*").length;
      }
    };
  }

})();
