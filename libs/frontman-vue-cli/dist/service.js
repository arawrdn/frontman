'use strict';

var Web = require('stream/web');
var Fs = require('fs');
var Nodepath = require('path');
var module$1 = require('module');
var Nodebuffer = require('buffer');
var Nodechild_process = require('child_process');
var Webpack = require('webpack');

var _documentCurrentScript = typeof document !== 'undefined' ? document.currentScript : null;
function _interopNamespace(e) {
  if (e && e.__esModule) return e;
  var n = Object.create(null);
  if (e) {
    Object.keys(e).forEach(function (k) {
      if (k !== 'default') {
        var d = Object.getOwnPropertyDescriptor(e, k);
        Object.defineProperty(n, k, d.get ? d : {
          enumerable: true,
          get: function () { return e[k]; }
        });
      }
    });
  }
  n.default = e;
  return Object.freeze(n);
}

var Web__namespace = /*#__PURE__*/_interopNamespace(Web);
var Fs__namespace = /*#__PURE__*/_interopNamespace(Fs);
var Nodepath__namespace = /*#__PURE__*/_interopNamespace(Nodepath);
var Nodebuffer__namespace = /*#__PURE__*/_interopNamespace(Nodebuffer);
var Nodechild_process__namespace = /*#__PURE__*/_interopNamespace(Nodechild_process);
var Webpack__namespace = /*#__PURE__*/_interopNamespace(Webpack);

var __getOwnPropNames = Object.getOwnPropertyNames;
var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
  get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
}) : x)(function(x) {
  if (typeof require !== "undefined") return require.apply(this, arguments);
  throw Error('Dynamic require of "' + x + '" is not supported');
});
var __commonJS = (cb, mod) => function __require2() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};

// ../../node_modules/@vscode/ripgrep/lib/index.js
var require_lib = __commonJS({
  "../../node_modules/@vscode/ripgrep/lib/index.js"(exports$1, module) {
    var path = __require("path");
    module.exports.rgPath = path.join(__dirname, `../bin/rg${process.platform === "win32" ? ".exe" : ""}`);
  }
});

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_JsError.js
function panic(msg) {
  throw new Error(`Panic! ` + msg);
}

// ../../node_modules/@rescript/runtime/lib/es6/Primitive_option.js
function some(x) {
  if (x === void 0) {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: 0
    };
  } else if (x !== null && x.BS_PRIVATE_NESTED_SOME_NONE !== void 0) {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: x.BS_PRIVATE_NESTED_SOME_NONE + 1 | 0
    };
  } else {
    return x;
  }
}
function fromNullable(x) {
  if (x == null) {
    return;
  } else {
    return some(x);
  }
}
function fromNull(x) {
  if (x === null) {
    return;
  } else {
    return some(x);
  }
}
function valFromOption(x) {
  if (x === null || x.BS_PRIVATE_NESTED_SOME_NONE === void 0) {
    return x;
  }
  let depth = x.BS_PRIVATE_NESTED_SOME_NONE;
  if (depth === 0) {
    return;
  } else {
    return {
      BS_PRIVATE_NESTED_SOME_NONE: depth - 1 | 0
    };
  }
}

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Option.js
function forEach(opt, f) {
  if (opt !== void 0) {
    return f(valFromOption(opt));
  }
}
function getOrThrow(x, message3) {
  if (x !== void 0) {
    return valFromOption(x);
  } else {
    return panic("Option.getOrThrow called for None value");
  }
}
function mapOr(opt, $$default, f) {
  if (opt !== void 0) {
    return f(valFromOption(opt));
  } else {
    return $$default;
  }
}
function map(opt, f) {
  if (opt !== void 0) {
    return some(f(valFromOption(opt)));
  }
}
function flatMap(opt, f) {
  if (opt !== void 0) {
    return f(valFromOption(opt));
  }
}
function getOr(opt, $$default) {
  if (opt !== void 0) {
    return valFromOption(opt);
  } else {
    return $$default;
  }
}
function orElse(opt, other) {
  if (opt !== void 0) {
    return opt;
  } else {
    return other;
  }
}
function isSome(x) {
  return x !== void 0;
}
function isNone(x) {
  return x === void 0;
}

// ../frontman-core/src/FrontmanCore__Hosts.res.mjs
var apiHost = "api.frontman.sh";
var clientJs = "https://app.frontman.sh/frontman.es.js";
var clientCss = "https://app.frontman.sh/frontman.css";
var devClientJs = "http://localhost:5173/src/Main.res.mjs";

// src/FrontmanVueCli__Config.res.mjs
var host = process.env["FRONTMAN_HOST"];
var defaultHost = host !== void 0 ? host : apiHost;
function normalizeHost(host2) {
  let trimmed = host2.trim();
  let candidate = trimmed.includes("://") ? trimmed : "https://" + trimmed;
  try {
    let parsed = new URL(candidate);
    let port2 = parsed.port;
    let tmp;
    switch (port2) {
      case "":
      case "443":
        tmp = parsed.hostname;
        break;
      default:
        tmp = parsed.hostname + `:` + port2;
    }
    return tmp.toLowerCase();
  } catch (exn) {
    return trimmed.toLowerCase();
  }
}
function makeFromObject(config) {
  let host2 = normalizeHost(getOr(config.host, defaultHost));
  let isDev = getOr(config.isDev, host2 !== apiHost.toLowerCase());
  let projectRoot = getOr(orElse(config.projectRoot, orElse(process.env["PROJECT_ROOT"], process.env["PWD"])), ".");
  let sourceRoot = getOr(config.sourceRoot, projectRoot);
  let basePath = getOr(config.basePath, "frontman");
  let serverName = getOr(config.serverName, "frontman-vue-cli");
  let serverVersion = getOr(config.serverVersion, "1.0.0");
  let isLightTheme = getOr(config.isLightTheme, false);
  let baseUrl = getOr(config.clientUrl, getOr(process.env["FRONTMAN_CLIENT_URL"], isDev ? devClientJs : clientJs));
  let url2 = new URL(baseUrl);
  if (url2.searchParams.has("clientName")) ; else {
    url2.searchParams.set("clientName", "vue-cli");
  }
  if (url2.searchParams.has("host")) ; else {
    url2.searchParams.set("host", host2);
  }
  let clientUrl = url2.href;
  return {
    isDev,
    projectRoot,
    sourceRoot,
    basePath,
    serverName,
    serverVersion,
    host: host2,
    clientUrl,
    clientCssUrl: orElse(config.clientCssUrl, isDev ? void 0 : clientCss),
    entrypointUrl: config.entrypointUrl,
    isLightTheme
  };
}

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_String.js
function indexOfOpt(s2, search) {
  let index = s2.indexOf(search);
  if (index !== -1) {
    return index;
  }
}
function isEmpty(s2) {
  return s2.length === 0;
}

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Dict.js
var forEachWithKey = ((dict3, f) => {
  for (var i in dict3) {
    f(dict3[i], i);
  }
});

// ../frontman-core/src/FrontmanCore__CORS.res.mjs
var corsHeaders = Object.fromEntries([
  [
    "Access-Control-Allow-Origin",
    "*"
  ],
  [
    "Access-Control-Allow-Methods",
    "GET, POST, OPTIONS"
  ],
  [
    "Access-Control-Allow-Headers",
    "Content-Type"
  ]
]);
function withCors(response) {
  let headers2 = response.headers;
  forEachWithKey(corsHeaders, (value, key) => {
    headers2.set(key, value);
  });
  return response;
}
function handlePreflight() {
  return new Response(null, {
    status: 204,
    headers: some(corsHeaders)
  });
}

// ../frontman-core/src/FrontmanCore__UIShell.res.mjs
function generateHTML(config) {
  let clientCssTag = mapOr(config.clientCssUrl, "", (url2) => `<link rel="stylesheet" href="` + url2 + `">`);
  let entrypointTemplate = mapOr(config.entrypointUrl, "", (url2) => `<script type="template" id="frontman-entrypoint-url">` + url2 + `</script>`);
  let themeClass = config.isLightTheme ? "" : "dark";
  let openrouterKey = flatMap(process.env["OPENROUTER_API_KEY"], (key) => {
    if (key !== "") {
      return key;
    }
  });
  let configObj = Object.fromEntries([
    [
      "framework",
      config.frameworkLabel
    ],
    [
      "basePath",
      config.basePath
    ]
  ]);
  forEach(openrouterKey, (key) => {
    configObj["openrouterKeyValue"] = key;
  });
  let payload = JSON.stringify(configObj);
  let runtimeConfigScript = `<script>window.__frontmanRuntime=` + payload + `</script>`;
  return `<!DOCTYPE html>
<html lang="en" class="` + themeClass + `">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Frontman</title>
    ` + entrypointTemplate + `
    ` + clientCssTag + `
    <style>
      html, body, #root {
        margin: 0;
        padding: 0;
        height: 100%;
        width: 100%;
      }
    </style>
</head>
<body>
    <div id="root"></div>
    ` + runtimeConfigScript + `
    <script>if(typeof process==="undefined"){window.process={env:{NODE_ENV:"production"}}}</script>
    <script type="module" src="` + config.clientUrl + `"></script>
</body>
</html>`;
}
function serve(config) {
  let html = generateHTML(config);
  let headers2 = Object.fromEntries([[
    "Content-Type",
    "text/html"
  ]]);
  return new Response(html, {
    headers: some(headers2)
  });
}
function serveWithEntrypoint(config, entrypointUrl) {
  return serve(entrypointUrl !== void 0 ? {
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
    basePath: config.basePath,
    serverName: config.serverName,
    serverVersion: config.serverVersion,
    clientUrl: config.clientUrl,
    clientCssUrl: config.clientCssUrl,
    entrypointUrl,
    isLightTheme: config.isLightTheme,
    frameworkLabel: config.frameworkLabel
  } : config);
}

// ../../node_modules/@rescript/runtime/lib/es6/Primitive_int.js
function min(x, y) {
  if (x < y) {
    return x;
  } else {
    return y;
  }
}
function max(x, y) {
  if (x > y) {
    return x;
  } else {
    return y;
  }
}
function div(x, y) {
  if (y === 0) {
    throw {
      RE_EXN_ID: "Division_by_zero",
      Error: new Error()
    };
  }
  return x / y | 0;
}
function mod_(x, y) {
  if (y === 0) {
    throw {
      RE_EXN_ID: "Division_by_zero",
      Error: new Error()
    };
  }
  return x % y;
}

// ../../node_modules/@rescript/runtime/lib/es6/Primitive_exceptions.js
function isExtension(e) {
  if (e == null) {
    return false;
  } else {
    return typeof e.RE_EXN_ID === "string";
  }
}
function internalToException(e) {
  if (isExtension(e)) {
    return e;
  } else {
    return {
      RE_EXN_ID: "JsExn",
      _1: e
    };
  }
}
var idMap = {};
function create(str) {
  let v = idMap[str];
  if (v !== void 0) {
    let id = v + 1 | 0;
    idMap[str] = id;
    return str + ("/" + id);
  }
  idMap[str] = 1;
  return str;
}

// ../../node_modules/sury/src/Sury.res.mjs
var immutableEmpty = {};
var immutableEmpty$1 = [];
function capitalize(string3) {
  return string3.slice(0, 1).toUpperCase() + string3.slice(1);
}
var copy = ((d2) => ({ ...d2 }));
function fromString(string3) {
  let _idx = 0;
  while (true) {
    let idx = _idx;
    let match = string3[idx];
    if (match === void 0) {
      return `"` + string3 + `"`;
    }
    switch (match) {
      case '"':
      case "\n":
        return JSON.stringify(string3);
      default:
        _idx = idx + 1 | 0;
        continue;
    }
  }
}
function toArray2(path) {
  if (path === "") {
    return [];
  } else {
    return JSON.parse(path.split(`"]["`).join(`","`));
  }
}
var vendor = "sury";
var s = Symbol(vendor);
var $$Error = /* @__PURE__ */ create("Sury.Error");
var constField = "const";
function isOptional(schema3) {
  let match = schema3.type;
  switch (match) {
    case "undefined":
      return true;
    case "union":
      return "undefined" in schema3.has;
    default:
      return false;
  }
}
function has(acc, flag) {
  return (acc & flag) !== 0;
}
var flags = {
  unknown: 1,
  string: 2,
  number: 4,
  boolean: 8,
  undefined: 16,
  null: 32,
  object: 64,
  array: 128,
  union: 256,
  ref: 512,
  bigint: 1024,
  nan: 2048,
  "function": 4096,
  instance: 8192,
  never: 16384,
  symbol: 32768
};
function stringify(unknown2) {
  let tagFlag = flags[typeof unknown2];
  if (tagFlag & 16) {
    return "undefined";
  }
  if (!(tagFlag & 64)) {
    if (tagFlag & 2) {
      return `"` + unknown2 + `"`;
    } else if (tagFlag & 1024) {
      return unknown2 + `n`;
    } else {
      return unknown2.toString();
    }
  }
  if (unknown2 === null) {
    return "null";
  }
  if (Array.isArray(unknown2)) {
    let string3 = "[";
    for (let i = 0, i_finish = unknown2.length; i < i_finish; ++i) {
      if (i !== 0) {
        string3 = string3 + ", ";
      }
      string3 = string3 + stringify(unknown2[i]);
    }
    return string3 + "]";
  }
  if (unknown2.constructor !== Object) {
    return Object.prototype.toString.call(unknown2);
  }
  let keys = Object.keys(unknown2);
  let string$1 = "{ ";
  for (let i$1 = 0, i_finish$1 = keys.length; i$1 < i_finish$1; ++i$1) {
    let key = keys[i$1];
    let value = unknown2[key];
    string$1 = string$1 + key + `: ` + stringify(value) + `; `;
  }
  return string$1 + "}";
}
function toExpression(schema3) {
  let tag = schema3.type;
  let $$const = schema3.const;
  let name13 = schema3.name;
  if (name13 !== void 0) {
    return name13;
  }
  if ($$const !== void 0) {
    return stringify($$const);
  }
  let format = schema3.format;
  let anyOf = schema3.anyOf;
  if (anyOf !== void 0) {
    return anyOf.map(toExpression).join(" | ");
  }
  if (format !== void 0) {
    return format;
  }
  switch (tag) {
    case "nan":
      return "NaN";
    case "object":
      let additionalItems = schema3.additionalItems;
      let properties = schema3.properties;
      let locations = Object.keys(properties);
      if (locations.length === 0) {
        if (typeof additionalItems === "object") {
          return `{ [key: string]: ` + toExpression(additionalItems) + `; }`;
        } else {
          return `{}`;
        }
      } else {
        return `{ ` + locations.map((location) => location + `: ` + toExpression(properties[location]) + `;`).join(" ") + ` }`;
      }
    default:
      if (schema3.b) {
        return tag;
      }
      switch (tag) {
        case "instance":
          return schema3.class.name;
        case "array":
          let additionalItems$1 = schema3.additionalItems;
          let items = schema3.items;
          if (typeof additionalItems$1 !== "object") {
            return `[` + items.map((item) => toExpression(item.schema)).join(", ") + `]`;
          }
          let itemName = toExpression(additionalItems$1);
          return (additionalItems$1.type === "union" ? `(` + itemName + `)` : itemName) + "[]";
        default:
          return tag;
      }
  }
}
var SuryError = class extends Error {
  constructor(code, flag, path) {
    super();
    this.flag = flag;
    this.code = code;
    this.path = path;
  }
};
var d = Object.defineProperty;
var p = SuryError.prototype;
d(p, "message", {
  get() {
    return message(this);
  }
});
d(p, "reason", {
  get() {
    return reason(this);
  }
});
d(p, "name", { value: "SuryError" });
d(p, "s", { value: s });
d(p, "_1", {
  get() {
    return this;
  }
});
d(p, "RE_EXN_ID", {
  value: $$Error
});
var Schema = function(type) {
  this.type = type;
};
var sp = /* @__PURE__ */ Object.create(null);
d(sp, "with", {
  get() {
    return (fn, ...args) => fn(this, ...args);
  }
});
Schema.prototype = sp;
function getOrRethrow(exn) {
  if (exn && exn.s === s) {
    return exn;
  }
  throw exn;
}
function reason(error, nestedLevelOpt) {
  let nestedLevel = nestedLevelOpt !== void 0 ? nestedLevelOpt : 0;
  let reason$1 = error.code;
  if (typeof reason$1 !== "object") {
    return "Encountered unexpected async transform or refine. Use parseAsyncOrThrow operation instead";
  }
  switch (reason$1.TAG) {
    case "OperationFailed":
      return reason$1._0;
    case "InvalidOperation":
      return reason$1.description;
    case "InvalidType":
      let unionErrors = reason$1.unionErrors;
      let m = `Expected ` + toExpression(reason$1.expected) + `, received ` + stringify(reason$1.received);
      if (unionErrors !== void 0) {
        let lineBreak = `
` + " ".repeat(nestedLevel << 1);
        let reasonsDict = {};
        for (let idx = 0, idx_finish = unionErrors.length; idx < idx_finish; ++idx) {
          let error$1 = unionErrors[idx];
          let reason$2 = reason(error$1, nestedLevel + 1);
          let nonEmptyPath = error$1.path;
          let location = nonEmptyPath === "" ? "" : `At ` + nonEmptyPath + `: `;
          let line = `- ` + location + reason$2;
          if (!reasonsDict[line]) {
            reasonsDict[line] = 1;
            m = m + lineBreak + line;
          }
        }
      }
      return m;
    case "UnsupportedTransformation":
      return `Unsupported transformation from ` + toExpression(reason$1.from) + ` to ` + toExpression(reason$1.to);
    case "ExcessField":
      return `Unrecognized key "` + reason$1._0 + `"`;
    case "InvalidJsonSchema":
      return toExpression(reason$1._0) + ` is not valid JSON`;
  }
}
function message(error) {
  let op = error.flag;
  let text = "Failed ";
  if (op & 2) {
    text = text + "async ";
  }
  text = text + (op & 1 ? op & 4 ? "asserting" : "parsing" : "converting");
  if (op & 8) {
    text = text + " to JSON" + (op & 16 ? " string" : "");
  }
  let nonEmptyPath = error.path;
  let tmp = nonEmptyPath === "" ? "" : ` at ` + nonEmptyPath;
  return text + tmp + `: ` + reason(error, void 0);
}
var globalConfig = {
  a: "strip"};
var shakenRef = "as";
var shakenTraps = {
  get: (target, prop) => {
    let l = target[shakenRef];
    if (l === void 0) {
      return target[prop];
    }
    if (prop === shakenRef) {
      return target[prop];
    }
    let l$1 = valFromOption(l);
    let message3 = `Schema S.` + l$1 + ` is not enabled. To start using it, add S.enable` + capitalize(l$1) + `() at the project root.`;
    throw new Error(`[Sury] ` + message3);
  }
};
function shaken(apiName) {
  let mut = new Schema("never");
  mut[shakenRef] = apiName;
  return new Proxy(mut, shakenTraps);
}
var unknown = new Schema("unknown");
var bool = new Schema("boolean");
var string = new Schema("string");
var int = new Schema("number");
int.format = "int32";
var float = new Schema("number");
var unit = new Schema("undefined");
unit.const = void 0;
var copyWithoutCache = ((schema3) => {
  let c2 = new Schema(schema3.type);
  for (let k2 in schema3) {
    if (k2 > "a" || k2 === "$ref" || k2 === "$defs") {
      c2[k2] = schema3[k2];
    }
  }
  return c2;
});
function updateOutput(schema3, fn) {
  let root = copyWithoutCache(schema3);
  let mut = root;
  while (mut.to) {
    let next = copyWithoutCache(mut.to);
    mut.to = next;
    mut = next;
  }
  fn(mut);
  return root;
}
function embed(b, value) {
  let e = b.g.e;
  let l = e.length;
  e[l] = value;
  return `e[` + l + `]`;
}
function inlineConst(b, schema3) {
  let tagFlag = flags[schema3.type];
  let $$const = schema3.const;
  if (tagFlag & 16) {
    return "void 0";
  } else if (tagFlag & 2) {
    return fromString($$const);
  } else if (tagFlag & 1024) {
    return $$const + "n";
  } else if (tagFlag & 45056) {
    return embed(b, schema3.const);
  } else {
    return $$const;
  }
}
function inlineLocation(b, location) {
  let key = `"` + location + `"`;
  let i = b.g[key];
  if (i !== void 0) {
    return i;
  }
  let inlinedLocation = fromString(location);
  b.g[key] = inlinedLocation;
  return inlinedLocation;
}
function secondAllocate(v) {
  let b = this;
  b.l = b.l + "," + v;
}
function initialAllocate(v) {
  let b = this;
  b.l = v;
  b.a = secondAllocate;
}
function rootScope(flag, defs) {
  let global2 = {
    c: "",
    l: "",
    a: initialAllocate,
    v: -1,
    o: flag,
    f: "",
    e: [],
    d: defs
  };
  global2.g = global2;
  return global2;
}
function allocateScope(b) {
  delete b.a;
  let varsAllocation = b.l;
  if (varsAllocation === "") {
    return b.f + b.c;
  } else {
    return b.f + `let ` + varsAllocation + `;` + b.c;
  }
}
function varWithoutAllocation(global2) {
  let newCounter = global2.v + 1;
  global2.v = newCounter;
  return `v` + newCounter;
}
function _var(_b) {
  return this.i;
}
function _notVar(b) {
  let val2 = this;
  let v = varWithoutAllocation(b.g);
  let i = val2.i;
  if (i === "") {
    val2.b.a(v);
  } else if (b.a !== void 0) {
    b.a(v + `=` + i);
  } else {
    b.c = b.c + (v + `=` + i + `;`);
    b.g.a(v);
  }
  val2.v = _var;
  val2.i = v;
  return v;
}
function allocateVal(b, schema3) {
  let v = varWithoutAllocation(b.g);
  b.a(v);
  return {
    b,
    v: _var,
    i: v,
    f: 0,
    type: schema3.type
  };
}
function val(b, initial, schema3) {
  return {
    b,
    v: _notVar,
    i: initial,
    f: 0,
    type: schema3.type
  };
}
function constVal(b, schema3) {
  return {
    b,
    v: _notVar,
    i: inlineConst(b, schema3),
    f: 0,
    type: schema3.type,
    const: schema3.const
  };
}
function asyncVal(b, initial) {
  return {
    b,
    v: _notVar,
    i: initial,
    f: 2,
    type: "unknown"
  };
}
function objectJoin(inlinedLocation, value) {
  return inlinedLocation + `:` + value + `,`;
}
function arrayJoin(_inlinedLocation, value) {
  return value + ",";
}
function make(b, isArray) {
  return {
    b,
    v: _notVar,
    i: "",
    f: 0,
    type: isArray ? "array" : "object",
    properties: {},
    additionalItems: "strict",
    j: isArray ? arrayJoin : objectJoin,
    c: 0,
    r: ""
  };
}
function add(objectVal, location, val2) {
  let inlinedLocation = inlineLocation(objectVal.b, location);
  objectVal.properties[location] = val2;
  if (val2.f & 2) {
    objectVal.r = objectVal.r + val2.i + ",";
    objectVal.i = objectVal.i + objectVal.j(inlinedLocation, `a[` + objectVal.c++ + `]`);
  } else {
    objectVal.i = objectVal.i + objectVal.j(inlinedLocation, val2.i);
  }
}
function complete(objectVal, isArray) {
  objectVal.i = isArray ? "[" + objectVal.i + "]" : "{" + objectVal.i + "}";
  if (objectVal.c) {
    objectVal.f = objectVal.f | 2;
    objectVal.i = `Promise.all([` + objectVal.r + `]).then(a=>(` + objectVal.i + `))`;
  }
  objectVal.additionalItems = "strict";
  return objectVal;
}
function addKey(b, input, key, val2) {
  return input.v(b) + `[` + key + `]=` + val2.i;
}
function set(b, input, val2) {
  if (input === val2) {
    return "";
  }
  let inputVar = input.v(b);
  let match = input.f & 2;
  let match$1 = val2.f & 2;
  if (match) {
    if (!match$1) {
      return inputVar + `=Promise.resolve(` + val2.i + `)`;
    }
  } else if (match$1) {
    input.f = input.f | 2;
    return inputVar + `=` + val2.i;
  }
  return inputVar + `=` + val2.i;
}
function get(b, targetVal, location) {
  let properties = targetVal.properties;
  let val2 = properties[location];
  if (val2 !== void 0) {
    return val2;
  }
  let schema3 = targetVal.additionalItems;
  let schema$1;
  if (schema3 === "strip" || schema3 === "strict") {
    if (schema3 === "strip") {
      throw new Error(`[Sury] The schema doesn't have additional items`);
    }
    throw new Error(`[Sury] The schema doesn't have additional items`);
  } else {
    schema$1 = schema3;
  }
  let val$1 = {
    b,
    v: _notVar,
    i: targetVal.v(b) + (`[` + fromString(location) + `]`),
    f: 0,
    type: schema$1.type
  };
  properties[location] = val$1;
  return val$1;
}
function setInlined(b, input, inlined) {
  return input.v(b) + `=` + inlined;
}
function map2(inlinedFn, input) {
  return {
    b: input.b,
    v: _notVar,
    i: inlinedFn + `(` + input.i + `)`,
    f: 0,
    type: "unknown"
  };
}
function $$throw(b, code, path) {
  throw new SuryError(code, b.g.o, path);
}
function failWithArg(b, path, fn, arg) {
  return embed(b, (arg2) => $$throw(b, fn(arg2), path)) + `(` + arg + `)`;
}
function withPathPrepend(b, input, path, maybeDynamicLocationVar, appendSafe, fn) {
  if (path === "" && maybeDynamicLocationVar === void 0) {
    return fn(b, input, path);
  }
  try {
    let $$catch2 = (b2, errorVar2) => {
      b2.c = errorVar2 + `.path=` + fromString(path) + `+` + (maybeDynamicLocationVar !== void 0 ? `'["'+` + maybeDynamicLocationVar + `+'"]'+` : "") + errorVar2 + `.path`;
    };
    let fn$1 = (b2) => fn(b2, input, "");
    let prevCode = b.c;
    b.c = "";
    let errorVar = varWithoutAllocation(b.g);
    let maybeResolveVal = $$catch2(b, errorVar);
    let catchCode = `if(` + (errorVar + `&&` + errorVar + `.s===s`) + `){` + b.c;
    b.c = "";
    let bb = {
      c: "",
      l: "",
      a: initialAllocate,
      f: "",
      g: b.g
    };
    let fnOutput = fn$1(bb);
    b.c = b.c + allocateScope(bb);
    let isNoop = fnOutput.i === input.i && b.c === "";
    if (appendSafe !== void 0) ;
    if (isNoop) {
      return fnOutput;
    }
    let isAsync2 = fnOutput.f & 2;
    let output = input === fnOutput ? input : appendSafe !== void 0 ? fnOutput : {
      b,
      v: _notVar,
      i: "",
      f: isAsync2 ? 2 : 0,
      type: "unknown"
    };
    let catchCode$1 = maybeResolveVal !== void 0 ? (catchLocation) => catchCode + (catchLocation === 1 ? `return ` + maybeResolveVal.i : set(b, output, maybeResolveVal)) + (`}else{throw ` + errorVar + `}`) : (param) => catchCode + `}throw ` + errorVar;
    b.c = prevCode + (`try{` + b.c + (isAsync2 ? setInlined(b, output, fnOutput.i + `.catch(` + errorVar + `=>{` + catchCode$1(1) + `})`) : set(b, output, fnOutput)) + `}catch(` + errorVar + `){` + catchCode$1(0) + `}`);
    return output;
  } catch (exn) {
    let error = getOrRethrow(exn);
    throw new SuryError(error.code, error.flag, path + "[]" + error.path);
  }
}
function validation(b, inputVar, schema3, negative) {
  let eq = negative ? "!==" : "===";
  let and_ = negative ? "||" : "&&";
  let exp = negative ? "!" : "";
  let tag = schema3.type;
  let tagFlag = flags[tag];
  if (tagFlag & 2048) {
    return exp + (`Number.isNaN(` + inputVar + `)`);
  }
  if (constField in schema3) {
    return inputVar + eq + inlineConst(b, schema3);
  }
  if (tagFlag & 4) {
    return `typeof ` + inputVar + eq + `"` + tag + `"`;
  }
  if (tagFlag & 64) {
    return `typeof ` + inputVar + eq + `"` + tag + `"` + and_ + exp + inputVar;
  }
  if (tagFlag & 128) {
    return exp + `Array.isArray(` + inputVar + `)`;
  }
  if (!(tagFlag & 8192)) {
    return `typeof ` + inputVar + eq + `"` + tag + `"`;
  }
  let c2 = inputVar + ` instanceof ` + embed(b, schema3.class);
  if (negative) {
    return `!(` + c2 + `)`;
  } else {
    return c2;
  }
}
function refinement(b, inputVar, schema3, negative) {
  let eq = negative ? "!==" : "===";
  let and_ = negative ? "||" : "&&";
  let not_ = negative ? "" : "!";
  let lt = negative ? ">" : "<";
  let gt = negative ? "<" : ">";
  let match = schema3.type;
  let tag;
  let exit = 0;
  let match$1 = schema3.const;
  if (match$1 !== void 0) {
    return "";
  }
  let match$2 = schema3.format;
  if (match$2 !== void 0) {
    switch (match$2) {
      case "int32":
        return and_ + inputVar + lt + `2147483647` + and_ + inputVar + gt + `-2147483648` + and_ + inputVar + `%1` + eq + `0`;
      case "port":
      case "json":
        exit = 2;
        break;
    }
  } else {
    exit = 2;
  }
  if (exit === 2) {
    switch (match) {
      case "number":
        {
          return and_ + not_ + `Number.isNaN(` + inputVar + `)`;
        }
      case "array":
      case "object":
        tag = match;
        break;
      default:
        return "";
    }
  }
  let additionalItems = schema3.additionalItems;
  let items = schema3.items;
  let length3 = items.length;
  let code = tag === "array" ? additionalItems === "strip" || additionalItems === "strict" ? additionalItems === "strip" ? and_ + inputVar + `.length` + gt + length3 : and_ + inputVar + `.length` + eq + length3 : "" : additionalItems === "strip" ? "" : and_ + not_ + `Array.isArray(` + inputVar + `)`;
  for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
    let match$3 = items[idx];
    let location = match$3.location;
    let item = match$3.schema;
    let itemCode;
    if (constField in item || schema3.unnest) {
      let inlinedLocation = inlineLocation(b, location);
      itemCode = validation(b, inputVar + (`[` + inlinedLocation + `]`), item, negative);
    } else if (item.items) {
      let inlinedLocation$1 = inlineLocation(b, location);
      let inputVar$1 = inputVar + (`[` + inlinedLocation$1 + `]`);
      itemCode = validation(b, inputVar$1, item, negative) + refinement(b, inputVar$1, item, negative);
    } else {
      itemCode = "";
    }
    if (itemCode !== "") {
      code = code + and_ + itemCode;
    }
  }
  return code;
}
function makeRefinedOf(b, input, schema3) {
  let mut = {
    b,
    v: input.v,
    i: input.i,
    f: input.f,
    type: schema3.type
  };
  let loop = (mut2, schema4) => {
    if (constField in schema4) {
      mut2.const = schema4.const;
    }
    let items = schema4.items;
    if (items === void 0) {
      return;
    }
    let properties = {};
    items.forEach((item) => {
      let schema5 = item.schema;
      let isConst = constField in schema5;
      if (!(isConst || schema5.items)) {
        return;
      }
      let tmp;
      if (isConst) {
        tmp = inlineConst(b, schema5);
      } else {
        let inlinedLocation = inlineLocation(b, item.location);
        tmp = mut2.v(b) + (`[` + inlinedLocation + `]`);
      }
      let mut$1 = {
        b: mut2.b,
        v: _notVar,
        i: tmp,
        f: 0,
        type: schema5.type
      };
      loop(mut$1, schema5);
      properties[item.location] = mut$1;
    });
    mut2.properties = properties;
    mut2.additionalItems = unknown;
  };
  loop(mut, schema3);
  return mut;
}
function typeFilterCode(b, schema3, input, path) {
  if (schema3.noValidation || flags[schema3.type] & 17153) {
    return "";
  }
  let inputVar = input.v(b);
  return `if(` + validation(b, inputVar, schema3, true) + refinement(b, inputVar, schema3, true) + `){` + failWithArg(b, path, (input2) => ({
    TAG: "InvalidType",
    expected: schema3,
    received: input2
  }), inputVar) + `}`;
}
function unsupportedTransform(b, from, target, path) {
  return $$throw(b, {
    TAG: "UnsupportedTransformation",
    from,
    to: target
  }, path);
}
function noopOperation(i) {
  return i;
}
function setHas(has2, tag) {
  has2[tag === "union" || tag === "ref" ? "unknown" : tag] = true;
}
var jsonName = `JSON`;
var jsonString = shaken("jsonString");
function inputToString(b, input) {
  return val(b, `""+` + input.i, string);
}
function parse(prevB, schema3, inputArg, path) {
  let b = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: prevB.g
  };
  if (schema3.$defs) {
    b.g.d = schema3.$defs;
  }
  let input = inputArg;
  let isFromLiteral = constField in input;
  let isSchemaLiteral = constField in schema3;
  let isSameTag = input.type === schema3.type;
  let schemaTagFlag = flags[schema3.type];
  let inputTagFlag = flags[input.type];
  let isUnsupported = false;
  if (!(schemaTagFlag & 257 || schema3.format === "json")) {
    if (schema3.name === jsonName && !(inputTagFlag & 1)) {
      if (!(inputTagFlag & 14)) {
        if (inputTagFlag & 1024) {
          input = inputToString(b, input);
        } else {
          isUnsupported = true;
        }
      }
    } else if (isSchemaLiteral) {
      if (isFromLiteral) {
        if (input.const !== schema3.const) {
          input = constVal(b, schema3);
        }
      } else if (inputTagFlag & 2 && schemaTagFlag & 3132) {
        let inputVar = input.v(b);
        b.f = schema3.noValidation ? "" : input.i + `==="` + schema3.const + `"||` + failWithArg(b, path, (input2) => ({
          TAG: "InvalidType",
          expected: schema3,
          received: input2
        }), inputVar) + `;`;
        input = constVal(b, schema3);
      } else if (schema3.noValidation) {
        input = constVal(b, schema3);
      } else {
        b.f = typeFilterCode(prevB, schema3, input, path);
        input.type = schema3.type;
        input.const = schema3.const;
      }
    } else if (isFromLiteral && !isSchemaLiteral) {
      if (!isSameTag) {
        if (schemaTagFlag & 2 && inputTagFlag & 3132) {
          let $$const = "" + input.const;
          input = {
            b,
            v: _notVar,
            i: `"` + $$const + `"`,
            f: 0,
            type: "string",
            const: $$const
          };
        } else {
          isUnsupported = true;
        }
      }
    } else if (inputTagFlag & 1) {
      let ref = schema3.$ref;
      if (ref !== void 0) {
        let defs = b.g.d;
        let identifier = ref.slice(8);
        let def = defs[identifier];
        let flag = schema3.noValidation ? (b.g.o | 1) ^ 1 : b.g.o;
        let fn = def[flag];
        let recOperation;
        if (fn !== void 0) {
          let fn$1 = valFromOption(fn);
          recOperation = fn$1 === 0 ? embed(b, def) + (`[` + flag + `]`) : embed(b, fn$1);
        } else {
          def[flag] = 0;
          let fn$2 = internalCompile(def, flag, b.g.d);
          def[flag] = fn$2;
          recOperation = embed(b, fn$2);
        }
        input = withPathPrepend(b, input, path, void 0, void 0, (param, input2, param$1) => {
          let output = map2(recOperation, input2);
          if (def.isAsync === void 0) {
            let defsMut = copy(defs);
            defsMut[identifier] = unknown;
            isAsyncInternal(def, defsMut);
          }
          if (def.isAsync) {
            output.f = output.f | 2;
          }
          return output;
        });
        input.v(b);
      } else {
        if (b.g.o & 1) {
          b.f = typeFilterCode(prevB, schema3, input, path);
        }
        let refined = makeRefinedOf(b, input, schema3);
        input.type = refined.type;
        input.i = refined.i;
        input.v = refined.v;
        input.additionalItems = refined.additionalItems;
        input.properties = refined.properties;
        if (constField in refined) {
          input.const = refined.const;
        }
      }
    } else if (schemaTagFlag & 2 && inputTagFlag & 1036) {
      input = inputToString(b, input);
    } else if (!isSameTag) {
      if (inputTagFlag & 2) {
        let inputVar$1 = input.v(b);
        if (schemaTagFlag & 8) {
          let output = allocateVal(b, schema3);
          b.c = b.c + (`(` + output.i + `=` + inputVar$1 + `==="true")||` + inputVar$1 + `==="false"||` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema3,
            received: input2
          }), inputVar$1) + `;`);
          input = output;
        } else if (schemaTagFlag & 4) {
          let output$1 = val(b, `+` + inputVar$1, schema3);
          let outputVar = output$1.v(b);
          let match = schema3.format;
          b.c = b.c + (match !== void 0 ? `(` + refinement(b, outputVar, schema3, true).slice(2) + `)` : `Number.isNaN(` + outputVar + `)`) + (`&&` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema3,
            received: input2
          }), inputVar$1) + `;`);
          input = output$1;
        } else if (schemaTagFlag & 1024) {
          let output$2 = allocateVal(b, schema3);
          b.c = b.c + (`try{` + output$2.i + `=BigInt(` + inputVar$1 + `)}catch(_){` + failWithArg(b, path, (input2) => ({
            TAG: "InvalidType",
            expected: schema3,
            received: input2
          }), inputVar$1) + `}`);
          input = output$2;
        } else {
          isUnsupported = true;
        }
      } else if (inputTagFlag & 4 && schemaTagFlag & 1024) {
        input = val(b, `BigInt(` + input.i + `)`, schema3);
      } else {
        isUnsupported = true;
      }
    }
  }
  if (isUnsupported) {
    unsupportedTransform(b, input, schema3, path);
  }
  let compiler2 = schema3.compiler;
  if (compiler2 !== void 0) {
    input = compiler2(b, input, schema3, path);
  }
  if (input.t !== true) {
    let refiner = schema3.refiner;
    if (refiner !== void 0) {
      b.c = b.c + refiner(b, input.v(b), schema3, path);
    }
  }
  let to2 = schema3.to;
  if (to2 !== void 0) {
    let parser2 = schema3.parser;
    if (parser2 !== void 0) {
      input = parser2(b, input, schema3, path);
    }
    if (input.t !== true) {
      input = parse(b, to2, input, path);
    }
  }
  prevB.c = prevB.c + allocateScope(b);
  return input;
}
function isAsyncInternal(schema3, defs) {
  try {
    let b = rootScope(2, defs);
    let input = {
      b,
      v: _var,
      i: "i",
      f: 0,
      type: "unknown"
    };
    let output = parse(b, schema3, input, "");
    let isAsync2 = has(output.f, 2);
    schema3.isAsync = isAsync2;
    return isAsync2;
  } catch (exn) {
    getOrRethrow(exn);
    return false;
  }
}
function internalCompile(schema3, flag, defs) {
  let b = rootScope(flag, defs);
  if (flag & 8) {
    let output = reverse(schema3);
    jsonableValidation(output, output, "", flag);
  }
  let input = {
    b,
    v: _var,
    i: "i",
    f: 0,
    type: "unknown"
  };
  let schema$1 = flag & 4 ? updateOutput(schema3, (mut) => {
    let t = new Schema(unit.type);
    t.const = unit.const;
    t.noValidation = true;
    mut.to = t;
  }) : flag & 16 ? updateOutput(schema3, (mut) => {
    mut.to = jsonString;
  }) : schema3;
  let output$1 = parse(b, schema$1, input, "");
  let code = allocateScope(b);
  let isAsync2 = has(output$1.f, 2);
  schema$1.isAsync = isAsync2;
  if (code === "" && output$1 === input && !(flag & 2)) {
    return noopOperation;
  }
  let inlinedOutput = output$1.i;
  if (flag & 2 && !isAsync2 && !defs) {
    inlinedOutput = `Promise.resolve(` + inlinedOutput + `)`;
  }
  let inlinedFunction = `i=>{` + code + `return ` + inlinedOutput + `}`;
  let ctxVarValue1 = b.g.e;
  return new Function("e", "s", `return ` + inlinedFunction)(ctxVarValue1, s);
}
function reverse(schema3) {
  let reversedHead;
  let current = schema3;
  while (current) {
    let mut = copyWithoutCache(current);
    let next = mut.to;
    let to2 = reversedHead;
    if (to2 !== void 0) {
      mut.to = to2;
    } else {
      delete mut.to;
    }
    let parser2 = mut.parser;
    let serializer = mut.serializer;
    if (serializer !== void 0) {
      mut.parser = serializer;
    } else {
      delete mut.parser;
    }
    if (parser2 !== void 0) {
      mut.serializer = parser2;
    } else {
      delete mut.serializer;
    }
    let fromDefault = mut.fromDefault;
    let $$default = mut.default;
    if ($$default !== void 0) {
      mut.fromDefault = $$default;
    } else {
      delete mut.fromDefault;
    }
    if (fromDefault !== void 0) {
      mut.default = fromDefault;
    } else {
      delete mut.default;
    }
    let items = mut.items;
    if (items !== void 0) {
      let properties = {};
      let newItems = new Array(items.length);
      for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
        let item = items[idx];
        let reversed_schema = reverse(item.schema);
        let reversed_location = item.location;
        let reversed = {
          schema: reversed_schema,
          location: reversed_location
        };
        if (item.r) {
          reversed.r = item.r;
        }
        properties[item.location] = reversed_schema;
        newItems[idx] = reversed;
      }
      mut.items = newItems;
      let match = mut.properties;
      if (match !== void 0) {
        mut.properties = properties;
      }
    }
    if (typeof mut.additionalItems === "object") {
      mut.additionalItems = reverse(mut.additionalItems);
    }
    let anyOf = mut.anyOf;
    if (anyOf !== void 0) {
      let has2 = {};
      let newAnyOf = [];
      for (let idx$1 = 0, idx_finish$1 = anyOf.length; idx$1 < idx_finish$1; ++idx$1) {
        let s2 = anyOf[idx$1];
        let reversed$1 = reverse(s2);
        newAnyOf.push(reversed$1);
        setHas(has2, reversed$1.type);
      }
      mut.has = has2;
      mut.anyOf = newAnyOf;
    }
    let defs = mut.$defs;
    if (defs !== void 0) {
      let reversedDefs = {};
      for (let idx$2 = 0, idx_finish$2 = Object.keys(defs).length; idx$2 < idx_finish$2; ++idx$2) {
        let key = Object.keys(defs)[idx$2];
        reversedDefs[key] = reverse(defs[key]);
      }
      mut.$defs = reversedDefs;
    }
    reversedHead = mut;
    current = next;
  }
  return reversedHead;
}
function jsonableValidation(output, parent, path, flag) {
  let tagFlag = flags[output.type];
  if (tagFlag & 48129 || tagFlag & 16 && parent.type !== "object") {
    throw new SuryError({
      TAG: "InvalidJsonSchema",
      _0: parent
    }, flag, path);
  }
  if (tagFlag & 256) {
    output.anyOf.forEach((s2) => jsonableValidation(s2, parent, path, flag));
    return;
  }
  if (!(tagFlag & 192)) {
    return;
  }
  let additionalItems = output.additionalItems;
  if (additionalItems === "strip" || additionalItems === "strict") ; else {
    jsonableValidation(additionalItems, parent, path, flag);
  }
  let p2 = output.properties;
  if (p2 !== void 0) {
    let keys = Object.keys(p2);
    for (let idx = 0, idx_finish = keys.length; idx < idx_finish; ++idx) {
      let key = keys[idx];
      jsonableValidation(p2[key], parent, path, flag);
    }
    return;
  }
  output.items.forEach((item) => jsonableValidation(item.schema, output, path + (`[` + fromString(item.location) + `]`), flag));
}
function getOutputSchema(_schema) {
  while (true) {
    let schema3 = _schema;
    let to2 = schema3.to;
    if (to2 === void 0) {
      return schema3;
    }
    _schema = to2;
    continue;
  }
}
function operationFn(s2, o) {
  if (o in s2) {
    return s2[o];
  }
  let f = internalCompile(o & 32 ? reverse(s2) : s2, o, 0);
  s2[o] = f;
  return f;
}
d(sp, "~standard", {
  get: function() {
    let schema3 = this;
    return {
      version: 1,
      vendor,
      validate: (input) => {
        try {
          return {
            value: operationFn(schema3, 1)(input)
          };
        } catch (exn) {
          let error = getOrRethrow(exn);
          return {
            issues: [{
              message: reason(error, void 0),
              path: error.path === "" ? void 0 : toArray2(error.path)
            }]
          };
        }
      }
    };
  }
});
function parseOrThrow(any, schema3) {
  return operationFn(schema3, 1)(any);
}
function reverseConvertToJsonOrThrow(value, schema3) {
  return operationFn(schema3, 40)(value);
}
var $$null = new Schema("null");
$$null.const = null;
function parse$1(value) {
  if (value === null) {
    return $$null;
  }
  let $$typeof = typeof value;
  let schema3;
  if ($$typeof === "object") {
    let i = new Schema("instance");
    i.class = value.constructor;
    schema3 = i;
  } else {
    schema3 = $$typeof === "undefined" ? unit : $$typeof === "number" ? Number.isNaN(value) ? new Schema("nan") : new Schema($$typeof) : new Schema($$typeof);
  }
  schema3.const = value;
  return schema3;
}
var defsPath = `#/$defs/`;
function appendRefiner(maybeExistingRefiner, refiner) {
  if (maybeExistingRefiner !== void 0) {
    return (b, inputVar, selfSchema, path) => maybeExistingRefiner(b, inputVar, selfSchema, path) + refiner(b, inputVar, selfSchema, path);
  } else {
    return refiner;
  }
}
var nullAsUnit = new Schema("null");
nullAsUnit.const = null;
nullAsUnit.to = unit;
function neverBuilder(b, input, selfSchema, path) {
  b.c = b.c + failWithArg(b, path, (input2) => ({
    TAG: "InvalidType",
    expected: selfSchema,
    received: input2
  }), input.i) + ";";
  return input;
}
var never = new Schema("never");
never.compiler = neverBuilder;
var nestedLoc = "BS_PRIVATE_NESTED_SOME_NONE";
function getItemCode(b, schema3, input, output, deopt, path) {
  try {
    let globalFlag = b.g.o;
    if (deopt) {
      b.g.o = globalFlag | 1;
    }
    let bb = {
      c: "",
      l: "",
      a: initialAllocate,
      f: "",
      g: b.g
    };
    let input$1 = deopt ? copy(input) : makeRefinedOf(bb, input, schema3);
    let itemOutput = parse(bb, schema3, input$1, path);
    if (itemOutput !== input$1) {
      itemOutput.b = bb;
      if (itemOutput.f & 2) {
        output.f = output.f | 2;
      }
      bb.c = bb.c + (output.v(b) + `=` + itemOutput.i);
    }
    b.g.o = globalFlag;
    return allocateScope(bb);
  } catch (exn) {
    return "throw " + embed(b, getOrRethrow(exn));
  }
}
function isPriority(tagFlag, byKey) {
  if (tagFlag & 8320 && "object" in byKey) {
    return true;
  } else if (tagFlag & 2048) {
    return "number" in byKey;
  } else {
    return false;
  }
}
function isWiderUnionSchema(schemaAnyOf, inputAnyOf) {
  return inputAnyOf.every((inputSchema12, idx) => {
    let schema3 = schemaAnyOf[idx];
    if (schema3 !== void 0 && !(flags[inputSchema12.type] & 9152) && inputSchema12.type === schema3.type) {
      return inputSchema12.const === schema3.const;
    } else {
      return false;
    }
  });
}
function compiler(b, input, selfSchema, path) {
  let schemas = selfSchema.anyOf;
  let inputAnyOf = input.anyOf;
  if (inputAnyOf !== void 0) {
    if (isWiderUnionSchema(schemas, inputAnyOf)) {
      return input;
    } else {
      return unsupportedTransform(b, input, selfSchema, path);
    }
  }
  let fail = (caught2) => embed(b, function() {
    let args = arguments;
    return $$throw(b, {
      TAG: "InvalidType",
      expected: selfSchema,
      received: args[0],
      unionErrors: args.length > 1 ? Array.from(args).slice(1) : void 0
    }, path);
  }) + `(` + input.v(b) + caught2 + `)`;
  let typeValidation = b.g.o & 1;
  let initialInline = input.i;
  let deoptIdx = -1;
  let lastIdx = schemas.length - 1 | 0;
  let byKey = {};
  let keys = [];
  for (let idx = 0; idx <= lastIdx; ++idx) {
    let target = selfSchema.to;
    let schema3 = target !== void 0 && !selfSchema.parser && target.type !== "union" ? updateOutput(schemas[idx], (mut) => {
      let refiner = selfSchema.refiner;
      if (refiner !== void 0) {
        mut.refiner = appendRefiner(mut.refiner, refiner);
      }
      mut.to = target;
    }) : schemas[idx];
    let tag = schema3.type;
    let tagFlag = flags[tag];
    if (!(tagFlag & 16 && "fromDefault" in selfSchema)) {
      if (tagFlag & 17153 || !(flags[input.type] & 1) && input.type !== tag) {
        deoptIdx = idx;
        byKey = {};
        keys = [];
      } else {
        let key = tagFlag & 8192 ? schema3.class.name : tag;
        let arr = byKey[key];
        if (arr !== void 0) {
          if (tagFlag & 64 && nestedLoc in schema3.properties) {
            arr.unshift(schema3);
          } else if (!(tagFlag & 2096)) {
            arr.push(schema3);
          }
        } else {
          if (isPriority(tagFlag, byKey)) {
            keys.unshift(key);
          } else {
            keys.push(key);
          }
          byKey[key] = [schema3];
        }
      }
    }
  }
  let deoptIdx$1 = deoptIdx;
  let byKey$1 = byKey;
  let keys$1 = keys;
  let start = "";
  let end = "";
  let caught = "";
  let exit = false;
  if (deoptIdx$1 !== -1) {
    for (let idx$1 = 0; idx$1 <= deoptIdx$1; ++idx$1) {
      if (!exit) {
        let schema$1 = schemas[idx$1];
        let itemCode = getItemCode(b, schema$1, input, input, true, path);
        if (itemCode) {
          let errorVar = `e` + idx$1;
          start = start + (`try{` + itemCode + `}catch(` + errorVar + `){`);
          end = "}" + end;
          caught = caught + `,` + errorVar;
        } else {
          exit = true;
        }
      }
    }
  }
  if (!exit) {
    let nextElse = false;
    let noop = "";
    for (let idx$2 = 0, idx_finish = keys$1.length; idx$2 < idx_finish; ++idx$2) {
      let schemas$1 = byKey$1[keys$1[idx$2]];
      let isMultiple = schemas$1.length > 1;
      let firstSchema = schemas$1[0];
      let cond = 0;
      let body;
      if (isMultiple) {
        let inputVar = input.v(b);
        let itemStart = "";
        let itemEnd = "";
        let itemNextElse = false;
        let itemNoop = {
          contents: ""
        };
        let caught$1 = "";
        let byDiscriminant = {};
        let itemIdx = 0;
        let lastIdx$1 = schemas$1.length - 1 | 0;
        while (itemIdx <= lastIdx$1) {
          let schema$2 = schemas$1[itemIdx];
          let itemCond = (constField in schema$2 ? validation(b, inputVar, schema$2, false) : "") + refinement(b, inputVar, schema$2, false).slice(2);
          let itemCode$1 = getItemCode(b, schema$2, input, input, false, path);
          if (itemCond) {
            if (itemCode$1) {
              let match = byDiscriminant[itemCond];
              if (match !== void 0) {
                if (typeof match === "string") {
                  byDiscriminant[itemCond] = [
                    match,
                    itemCode$1
                  ];
                } else {
                  match.push(itemCode$1);
                }
              } else {
                byDiscriminant[itemCond] = itemCode$1;
              }
            } else {
              itemNoop.contents = itemNoop.contents ? itemNoop.contents + `||` + itemCond : itemCond;
            }
          }
          if (!itemCond || itemIdx === lastIdx$1) {
            let accedDiscriminants = Object.keys(byDiscriminant);
            for (let idx$3 = 0, idx_finish$1 = accedDiscriminants.length; idx$3 < idx_finish$1; ++idx$3) {
              let discrim = accedDiscriminants[idx$3];
              let if_ = itemNextElse ? "else if" : "if";
              itemStart = itemStart + if_ + (`(` + discrim + `){`);
              let code = byDiscriminant[discrim];
              if (typeof code === "string") {
                itemStart = itemStart + code + "}";
              } else {
                let caught$2 = "";
                for (let idx$4 = 0, idx_finish$2 = code.length; idx$4 < idx_finish$2; ++idx$4) {
                  let code$1 = code[idx$4];
                  let errorVar$1 = `e` + idx$4;
                  itemStart = itemStart + (`try{` + code$1 + `}catch(` + errorVar$1 + `){`);
                  caught$2 = caught$2 + `,` + errorVar$1;
                }
                itemStart = itemStart + fail(caught$2) + "}".repeat(code.length) + "}";
              }
              itemNextElse = true;
            }
            byDiscriminant = {};
          }
          if (!itemCond) {
            if (itemCode$1) {
              if (itemNoop.contents) {
                let if_$1 = itemNextElse ? "else if" : "if";
                itemStart = itemStart + if_$1 + (`(!(` + itemNoop.contents + `)){`);
                itemEnd = "}" + itemEnd;
                itemNoop.contents = "";
                itemNextElse = false;
              }
              let errorVar$2 = `e` + itemIdx;
              itemStart = itemStart + ((itemNextElse ? "else{" : "") + `try{` + itemCode$1 + `}catch(` + errorVar$2 + `){`);
              itemEnd = (itemNextElse ? "}" : "") + "}" + itemEnd;
              caught$1 = caught$1 + `,` + errorVar$2;
              itemNextElse = false;
            } else {
              itemNoop.contents = "";
              itemIdx = lastIdx$1;
            }
          }
          itemIdx = itemIdx + 1;
        }
        cond = (inputVar2) => validation(b, inputVar2, {
          type: firstSchema.type,
          parser: 0
        }, false);
        if (itemNoop.contents) {
          if (itemStart) {
            if (typeValidation) {
              let if_$2 = itemNextElse ? "else if" : "if";
              itemStart = itemStart + if_$2 + (`(!(` + itemNoop.contents + `)){` + fail(caught$1) + `}`);
            }
          } else {
            let condBefore = cond;
            cond = (inputVar2) => condBefore(inputVar2) + (`&&(` + itemNoop.contents + `)`);
          }
        } else if (typeValidation && itemStart) {
          let errorCode = fail(caught$1);
          itemStart = itemStart + (itemNextElse ? `else{` + errorCode + `}` : errorCode);
        }
        body = itemStart + itemEnd;
      } else {
        cond = (inputVar) => validation(b, inputVar, firstSchema, false) + refinement(b, inputVar, firstSchema, false);
        body = getItemCode(b, firstSchema, input, input, false, path);
      }
      if (body || isPriority(flags[firstSchema.type], byKey$1)) {
        let if_$3 = nextElse ? "else if" : "if";
        start = start + if_$3 + (`(` + cond(input.v(b)) + `){` + body + `}`);
        nextElse = true;
      } else if (typeValidation) {
        let cond$1 = cond(input.v(b));
        noop = noop ? noop + `||` + cond$1 : cond$1;
      }
    }
    if (typeValidation || deoptIdx$1 === lastIdx) {
      let errorCode$1 = fail(caught);
      let tmp;
      if (noop) {
        let if_$4 = nextElse ? "else if" : "if";
        tmp = if_$4 + (`(!(` + noop + `)){` + errorCode$1 + `}`);
      } else {
        tmp = nextElse ? `else{` + errorCode$1 + `}` : errorCode$1;
      }
      start = start + tmp;
    }
  }
  b.c = b.c + start + end;
  let o = input.f & 2 ? asyncVal(b, `Promise.resolve(` + input.i + `)`) : input.v === _var ? b.c === "" && input.b.c === "" && (input.b.l === input.i + `=` + initialInline || initialInline === "i") ? (input.b.l = "", input.b.a = initialAllocate, input.v = _notVar, input.i = initialInline, input) : copy(input) : input;
  o.anyOf = selfSchema.anyOf;
  let to2 = selfSchema.to;
  o.type = to2 !== void 0 && to2.type !== "union" ? (o.t = true, getOutputSchema(to2).type) : "union";
  return o;
}
function factory(schemas) {
  let len = schemas.length;
  if (len === 1) {
    return schemas[0];
  }
  if (len !== 0) {
    let has2 = {};
    let anyOf = /* @__PURE__ */ new Set();
    for (let idx = 0, idx_finish = schemas.length; idx < idx_finish; ++idx) {
      let schema3 = schemas[idx];
      if (schema3.type === "union" && schema3.to === void 0) {
        schema3.anyOf.forEach((item) => {
          anyOf.add(item);
        });
        Object.assign(has2, schema3.has);
      } else {
        anyOf.add(schema3);
        setHas(has2, schema3.type);
      }
    }
    let mut = new Schema("union");
    mut.anyOf = Array.from(anyOf);
    mut.compiler = compiler;
    mut.has = has2;
    return mut;
  }
  throw new Error(`[Sury] S.union requires at least one item`);
}
function nestedNone() {
  let itemSchema = parse$1(0);
  let item = {
    schema: itemSchema,
    location: nestedLoc
  };
  let properties = {};
  properties[nestedLoc] = itemSchema;
  return {
    type: "object",
    serializer: (b, param, selfSchema, param$1) => constVal(b, selfSchema.to),
    additionalItems: "strip",
    items: [item],
    properties
  };
}
function parser(b, param, selfSchema, param$1) {
  return val(b, `{` + nestedLoc + `:` + getOutputSchema(selfSchema).items[0].schema.const + `}`, selfSchema.to);
}
function nestedOption(item) {
  return updateOutput(item, (mut) => {
    mut.to = nestedNone();
    mut.parser = parser;
  });
}
function factory$1(item, unitOpt) {
  let unit$1 = unitOpt !== void 0 ? unitOpt : unit;
  let match = getOutputSchema(item);
  let match$1 = match.type;
  switch (match$1) {
    case "undefined":
      return factory([
        unit$1,
        nestedOption(item)
      ]);
    case "union":
      let has2 = match.has;
      let anyOf = match.anyOf;
      return updateOutput(item, (mut) => {
        let mutHas = copy(has2);
        let newAnyOf = [];
        for (let idx = 0, idx_finish = anyOf.length; idx < idx_finish; ++idx) {
          let schema3 = anyOf[idx];
          let match2 = getOutputSchema(schema3);
          let match$12 = match2.type;
          let tmp;
          if (match$12 === "undefined") {
            mutHas[unit$1.type] = true;
            newAnyOf.push(unit$1);
            tmp = nestedOption(schema3);
          } else {
            let properties = match2.properties;
            if (properties !== void 0) {
              let nestedSchema = properties[nestedLoc];
              tmp = nestedSchema !== void 0 ? updateOutput(schema3, (mut2) => {
                let newItem_schema = {
                  type: nestedSchema.type,
                  parser: nestedSchema.parser,
                  const: nestedSchema.const + 1
                };
                let newItem = {
                  schema: newItem_schema,
                  location: nestedLoc
                };
                let properties2 = {};
                properties2[nestedLoc] = newItem_schema;
                mut2.items = [newItem];
                mut2.properties = properties2;
              }) : schema3;
            } else {
              tmp = schema3;
            }
          }
          newAnyOf.push(tmp);
        }
        if (newAnyOf.length === anyOf.length) {
          mutHas[unit$1.type] = true;
          newAnyOf.push(unit$1);
        }
        mut.anyOf = newAnyOf;
        mut.has = mutHas;
      });
    default:
      return factory([
        item,
        unit$1
      ]);
  }
}
var metadataId = `m:Array.refinements`;
function refinements(schema3) {
  let m = schema3[metadataId];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
function arrayCompiler(b, input, selfSchema, path) {
  let item = selfSchema.additionalItems;
  let inputVar = input.v(b);
  let iteratorVar = varWithoutAllocation(b.g);
  let bb = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: b.g
  };
  let itemInput = val(bb, inputVar + `[` + iteratorVar + `]`, unknown);
  let itemOutput = withPathPrepend(bb, itemInput, path, iteratorVar, void 0, (b2, input2, path2) => parse(b2, item, input2, path2));
  let itemCode = allocateScope(bb);
  let isTransformed = itemInput !== itemOutput;
  let output = isTransformed ? val(b, `new Array(` + inputVar + `.length)`, selfSchema) : input;
  output.type = selfSchema.type;
  output.additionalItems = selfSchema.additionalItems;
  if (isTransformed || itemCode !== "") {
    b.c = b.c + (`for(let ` + iteratorVar + `=0;` + iteratorVar + `<` + inputVar + `.length;++` + iteratorVar + `){` + itemCode + (isTransformed ? addKey(b, output, iteratorVar, itemOutput) : "") + `}`);
  }
  if (itemOutput.f & 2) {
    return asyncVal(output.b, `Promise.all(` + output.i + `)`);
  } else {
    return output;
  }
}
function factory$2(item) {
  let mut = new Schema("array");
  mut.additionalItems = item;
  mut.items = immutableEmpty$1;
  mut.compiler = arrayCompiler;
  return mut;
}
function dictCompiler(b, input, selfSchema, path) {
  let item = selfSchema.additionalItems;
  let inputVar = input.v(b);
  let keyVar = varWithoutAllocation(b.g);
  let bb = {
    c: "",
    l: "",
    a: initialAllocate,
    f: "",
    g: b.g
  };
  let itemInput = val(bb, inputVar + `[` + keyVar + `]`, unknown);
  let itemOutput = withPathPrepend(bb, itemInput, path, keyVar, void 0, (b2, input2, path2) => parse(b2, item, input2, path2));
  let itemCode = allocateScope(bb);
  let isTransformed = itemInput !== itemOutput;
  let output = isTransformed ? val(b, "{}", selfSchema) : input;
  output.type = selfSchema.type;
  output.additionalItems = selfSchema.additionalItems;
  if (isTransformed || itemCode !== "") {
    b.c = b.c + (`for(let ` + keyVar + ` in ` + inputVar + `){` + itemCode + (isTransformed ? addKey(b, output, keyVar, itemOutput) : "") + `}`);
  }
  if (!(itemOutput.f & 2)) {
    return output;
  }
  let resolveVar = varWithoutAllocation(b.g);
  let rejectVar = varWithoutAllocation(b.g);
  let asyncParseResultVar = varWithoutAllocation(b.g);
  let counterVar = varWithoutAllocation(b.g);
  let outputVar = output.v(b);
  return asyncVal(b, `new Promise((` + resolveVar + `,` + rejectVar + `)=>{let ` + counterVar + `=Object.keys(` + outputVar + `).length;for(let ` + keyVar + ` in ` + outputVar + `){` + outputVar + `[` + keyVar + `].then(` + asyncParseResultVar + `=>{` + outputVar + `[` + keyVar + `]=` + asyncParseResultVar + `;if(` + counterVar + `--===1){` + resolveVar + `(` + outputVar + `)}},` + rejectVar + `)}})`);
}
function factory$3(item) {
  let mut = new Schema("object");
  mut.properties = immutableEmpty;
  mut.items = immutableEmpty$1;
  mut.additionalItems = item;
  mut.compiler = dictCompiler;
  return mut;
}
var metadataId$1 = `m:String.refinements`;
function refinements$1(schema3) {
  let m = schema3[metadataId$1];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
var json = shaken("json");
function enableJson() {
  if (!json[shakenRef]) {
    return;
  }
  delete json.as;
  let jsonRef = new Schema("ref");
  jsonRef.$ref = defsPath + jsonName;
  jsonRef.name = jsonName;
  json.type = jsonRef.type;
  json.$ref = jsonRef.$ref;
  json.name = jsonName;
  let defs = {};
  defs[jsonName] = {
    type: "union",
    compiler,
    name: jsonName,
    has: {
      string: true,
      boolean: true,
      number: true,
      null: true,
      object: true,
      array: true
    },
    anyOf: [
      string,
      bool,
      float,
      $$null,
      factory$3(jsonRef),
      factory$2(jsonRef)
    ]
  };
  json.$defs = defs;
}
var metadataId$2 = `m:Int.refinements`;
function refinements$2(schema3) {
  let m = schema3[metadataId$2];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
var metadataId$3 = `m:Float.refinements`;
function refinements$3(schema3) {
  let m = schema3[metadataId$3];
  if (m !== void 0) {
    return m;
  } else {
    return [];
  }
}
function objectStrictModeCheck(b, input, items, selfSchema, path) {
  if (!(selfSchema.type === "object" && selfSchema.additionalItems === "strict" && b.g.o & 1)) {
    return;
  }
  let key = allocateVal(b, unknown);
  let keyVar = key.i;
  b.c = b.c + (`for(` + keyVar + ` in ` + input.v(b) + `){if(`);
  if (items.length !== 0) {
    for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
      let match = items[idx];
      if (idx !== 0) {
        b.c = b.c + "&&";
      }
      b.c = b.c + (keyVar + `!==` + inlineLocation(b, match.location));
    }
  } else {
    b.c = b.c + "true";
  }
  b.c = b.c + (`){` + failWithArg(b, path, (exccessFieldName) => ({
    TAG: "ExcessField",
    _0: exccessFieldName
  }), keyVar) + `}}`);
}
function schemaCompiler(b, input, selfSchema, path) {
  let additionalItems = selfSchema.additionalItems;
  let items = selfSchema.items;
  let isArray = flags[selfSchema.type] & 128;
  if (b.g.o & 64) {
    let objectVal = make(b, isArray);
    for (let idx = 0, idx_finish = items.length; idx < idx_finish; ++idx) {
      let match = items[idx];
      let location = match.location;
      add(objectVal, location, input.properties[location]);
    }
    return complete(objectVal, isArray);
  }
  let objectVal$1 = make(b, isArray);
  for (let idx$1 = 0, idx_finish$1 = items.length; idx$1 < idx_finish$1; ++idx$1) {
    let match$1 = items[idx$1];
    let location$1 = match$1.location;
    let itemInput = get(b, input, location$1);
    let inlinedLocation = inlineLocation(b, location$1);
    let path$1 = path + (`[` + inlinedLocation + `]`);
    add(objectVal$1, location$1, parse(b, match$1.schema, itemInput, path$1));
  }
  objectStrictModeCheck(b, input, items, selfSchema, path);
  if ((additionalItems !== "strip" || b.g.o & 32) && items.every((item) => objectVal$1.properties[item.location] === input.properties[item.location])) {
    input.additionalItems = "strip";
    return input;
  } else {
    return complete(objectVal$1, isArray);
  }
}
function definitionToSchema(definition) {
  if (typeof definition !== "object" || definition === null) {
    return parse$1(definition);
  }
  if (definition["~standard"]) {
    return definition;
  }
  if (Array.isArray(definition)) {
    for (let idx = 0, idx_finish = definition.length; idx < idx_finish; ++idx) {
      let schema3 = definitionToSchema(definition[idx]);
      let location = idx.toString();
      definition[idx] = {
        schema: schema3,
        location
      };
    }
    let mut = new Schema("array");
    mut.items = definition;
    mut.additionalItems = "strict";
    mut.compiler = schemaCompiler;
    return mut;
  }
  let cnstr = definition.constructor;
  if (cnstr && cnstr !== Object) {
    return {
      type: "instance",
      const: definition,
      class: cnstr
    };
  }
  let fieldNames = Object.keys(definition);
  let length3 = fieldNames.length;
  let items = [];
  for (let idx$1 = 0; idx$1 < length3; ++idx$1) {
    let location$1 = fieldNames[idx$1];
    let schema$1 = definitionToSchema(definition[location$1]);
    let item = {
      schema: schema$1,
      location: location$1
    };
    definition[location$1] = schema$1;
    items[idx$1] = item;
  }
  let mut$1 = new Schema("object");
  mut$1.items = items;
  mut$1.properties = definition;
  mut$1.additionalItems = globalConfig.a;
  mut$1.compiler = schemaCompiler;
  return mut$1;
}
function matches(schema3) {
  return schema3;
}
var ctx = {
  m: matches
};
function factory$4(definer) {
  return definitionToSchema(definer(ctx));
}
var js_schema = definitionToSchema;
function option(item) {
  return factory$1(item, unit);
}
var jsonSchemaMetadataId = `m:JSONSchema`;
function internalToJSONSchema(schema3, defs) {
  let jsonSchema = {};
  switch (schema3.type) {
    case "never":
      jsonSchema.not = {};
      break;
    case "unknown":
      break;
    case "string":
      let $$const = schema3.const;
      jsonSchema.type = "string";
      refinements$1(schema3).forEach((refinement2) => {
        let match = refinement2.kind;
        if (typeof match !== "object") {
          switch (match) {
            case "Email":
              jsonSchema.format = "email";
              return;
            case "Uuid":
              jsonSchema.format = "uuid";
              return;
            case "Cuid":
              return;
            case "Url":
              jsonSchema.format = "uri";
              return;
            case "Datetime":
              jsonSchema.format = "date-time";
              return;
          }
        } else {
          switch (match.TAG) {
            case "Min":
              jsonSchema.minLength = match.length;
              return;
            case "Max":
              jsonSchema.maxLength = match.length;
              return;
            case "Length":
              let length3 = match.length;
              jsonSchema.minLength = length3;
              jsonSchema.maxLength = length3;
              return;
            case "Pattern":
              jsonSchema.pattern = String(match.re);
              return;
          }
        }
      });
      if ($$const !== void 0) {
        jsonSchema.const = $$const;
      }
      break;
    case "number":
      let format = schema3.format;
      let $$const$1 = schema3.const;
      if (format !== void 0) {
        if (format === "int32") {
          jsonSchema.type = "integer";
          refinements$2(schema3).forEach((refinement2) => {
            let match = refinement2.kind;
            if (match.TAG === "Min") {
              jsonSchema.minimum = match.value;
            } else {
              jsonSchema.maximum = match.value;
            }
          });
        } else {
          jsonSchema.type = "integer";
          jsonSchema.maximum = 65535;
          jsonSchema.minimum = 0;
        }
      } else {
        jsonSchema.type = "number";
        refinements$3(schema3).forEach((refinement2) => {
          let match = refinement2.kind;
          if (match.TAG === "Min") {
            jsonSchema.minimum = match.value;
          } else {
            jsonSchema.maximum = match.value;
          }
        });
      }
      if ($$const$1 !== void 0) {
        jsonSchema.const = $$const$1;
      }
      break;
    case "boolean":
      let $$const$2 = schema3.const;
      jsonSchema.type = "boolean";
      if ($$const$2 !== void 0) {
        jsonSchema.const = $$const$2;
      }
      break;
    case "null":
      jsonSchema.type = "null";
      break;
    case "array":
      let additionalItems = schema3.additionalItems;
      let exit = 0;
      if (additionalItems === "strip" || additionalItems === "strict") {
        exit = 1;
      } else {
        jsonSchema.items = internalToJSONSchema(additionalItems, defs);
        jsonSchema.type = "array";
        refinements(schema3).forEach((refinement2) => {
          let match = refinement2.kind;
          switch (match.TAG) {
            case "Min":
              jsonSchema.minItems = match.length;
              return;
            case "Max":
              jsonSchema.maxItems = match.length;
              return;
            case "Length":
              let length3 = match.length;
              jsonSchema.maxItems = length3;
              jsonSchema.minItems = length3;
              return;
          }
        });
      }
      if (exit === 1) {
        let items = schema3.items.map((item) => internalToJSONSchema(item.schema, defs));
        let itemsNumber = items.length;
        jsonSchema.items = some(items);
        jsonSchema.type = "array";
        jsonSchema.minItems = itemsNumber;
        jsonSchema.maxItems = itemsNumber;
      }
      break;
    case "object":
      let additionalItems$1 = schema3.additionalItems;
      let exit$1 = 0;
      if (additionalItems$1 === "strip" || additionalItems$1 === "strict") {
        exit$1 = 1;
      } else {
        jsonSchema.type = "object";
        jsonSchema.additionalProperties = internalToJSONSchema(additionalItems$1, defs);
      }
      if (exit$1 === 1) {
        let properties = {};
        let required = [];
        schema3.items.forEach((item) => {
          let fieldSchema = internalToJSONSchema(item.schema, defs);
          if (!isOptional(item.schema)) {
            required.push(item.location);
          }
          properties[item.location] = fieldSchema;
        });
        jsonSchema.type = "object";
        jsonSchema.properties = properties;
        let tmp;
        tmp = additionalItems$1 === "strip" || additionalItems$1 === "strict" ? additionalItems$1 === "strip" : true;
        jsonSchema.additionalProperties = tmp;
        if (required.length !== 0) {
          jsonSchema.required = required;
        }
      }
      break;
    case "union":
      let literals = [];
      let items$1 = [];
      schema3.anyOf.forEach((childSchema) => {
        if (childSchema.type === "undefined") {
          return;
        }
        items$1.push(internalToJSONSchema(childSchema, defs));
        if (constField in childSchema) {
          literals.push(childSchema.const);
          return;
        }
      });
      let itemsNumber$1 = items$1.length;
      let $$default = schema3.default;
      if ($$default !== void 0) {
        jsonSchema.default = valFromOption($$default);
      }
      if (itemsNumber$1 === 1) {
        Object.assign(jsonSchema, items$1[0]);
      } else if (literals.length === itemsNumber$1) {
        jsonSchema.enum = literals;
      } else {
        jsonSchema.anyOf = items$1;
      }
      break;
    case "ref":
      let ref = schema3.$ref;
      if (ref === defsPath + jsonName) ; else {
        jsonSchema.$ref = ref;
      }
      break;
    default:
      throw new Error(`[Sury] Unexpected schema type`);
  }
  let m = schema3.description;
  if (m !== void 0) {
    jsonSchema.description = m;
  }
  let m$1 = schema3.title;
  if (m$1 !== void 0) {
    jsonSchema.title = m$1;
  }
  let deprecated = schema3.deprecated;
  if (deprecated !== void 0) {
    jsonSchema.deprecated = deprecated;
  }
  let examples = schema3.examples;
  if (examples !== void 0) {
    jsonSchema.examples = examples;
  }
  let schemaDefs = schema3.$defs;
  if (schemaDefs !== void 0) {
    Object.assign(defs, schemaDefs);
  }
  let metadataRawSchema = schema3[jsonSchemaMetadataId];
  if (metadataRawSchema !== void 0) {
    Object.assign(jsonSchema, metadataRawSchema);
  }
  return jsonSchema;
}
function toJSONSchema(schema3) {
  jsonableValidation(schema3, schema3, "", 8);
  let defs = {};
  let jsonSchema = internalToJSONSchema(schema3, defs);
  delete defs.JSON;
  let defsKeys = Object.keys(defs);
  if (defsKeys.length) {
    defsKeys.forEach((key) => {
      defs[key] = internalToJSONSchema(defs[key], 0);
    });
    jsonSchema.$defs = defs;
  }
  return jsonSchema;
}
var literal = js_schema;
var array = factory$2;
var dict = factory$3;
var union = factory;
var schema = factory$4;

// ../../node_modules/sury/src/S.res.mjs
var $$Error2 = $$Error;
var string2 = string;
var bool2 = bool;
var int2 = int;
var float2 = float;
var json2 = json;
var enableJson2 = enableJson;
var literal2 = literal;
var array2 = array;
var dict2 = dict;
var option2 = option;
var union2 = union;
var parseOrThrow2 = parseOrThrow;
var reverseConvertToJsonOrThrow2 = reverseConvertToJsonOrThrow;
var schema2 = schema;
var toJSONSchema2 = toJSONSchema;

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_JsExn.js
function fromException(exn) {
  if (exn.RE_EXN_ID === "JsExn") {
    return some(exn._1);
  }
}
var getOrUndefined = ((fieldName) => (t) => t && typeof t[fieldName] === "string" ? t[fieldName] : void 0);
var message2 = getOrUndefined("message");

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Promise.js
function $$catch(promise, callback) {
  return promise.catch((err) => callback(internalToException(err)));
}

// ../frontman-protocol/src/FrontmanProtocol__MCP.res.mjs
enableJson2();
var capabilitiesSchema = schema2((s2) => ({
  tools: s2.m(option2(dict2(json2))),
  resources: s2.m(option2(dict2(json2))),
  prompts: s2.m(option2(dict2(json2)))
}));
var infoSchema = schema2((s2) => ({
  name: s2.m(string2),
  version: s2.m(string2)
}));
schema2((s2) => ({
  protocolVersion: s2.m(string2),
  capabilities: s2.m(capabilitiesSchema),
  clientInfo: s2.m(infoSchema)
}));
schema2((s2) => ({
  protocolVersion: s2.m(string2),
  capabilities: s2.m(capabilitiesSchema),
  serverInfo: s2.m(infoSchema)
}));
schema2((s2) => ({
  callId: s2.m(string2),
  name: s2.m(string2),
  arguments: s2.m(option2(dict2(json2)))
}));
var toolResultContentSchema = schema2((s2) => ({
  type: s2.m(string2),
  text: s2.m(string2)
}));
schema2((s2) => ({
  code: s2.m(int2),
  message: s2.m(string2)
}));
var callToolResultSchema = schema2((s2) => ({
  content: s2.m(array2(toolResultContentSchema)),
  isError: s2.m(option2(bool2))
}));
schema2((s2) => ({
  tools: s2.m(array2(json2))
}));

// ../frontman-core/src/FrontmanCore__SSE.res.mjs
function formatEvent(eventType, data) {
  return `event: ` + eventType + `
data: ` + data + `

`;
}
function resultEvent(result) {
  let data = JSON.stringify(reverseConvertToJsonOrThrow2(result, callToolResultSchema));
  return formatEvent("result", data);
}
function errorEvent(result) {
  let data = JSON.stringify(reverseConvertToJsonOrThrow2(result, callToolResultSchema));
  return formatEvent("error", data);
}
function headers() {
  return Object.fromEntries([
    [
      "Content-Type",
      "text/event-stream"
    ],
    [
      "Cache-Control",
      "no-cache, no-transform"
    ],
    [
      "Connection",
      "keep-alive"
    ]
  ]);
}

// ../../node_modules/dom-element-to-component-source/dist/_commonjsHelpers-CqEciG1_.mjs
function c(e) {
  if (Object.prototype.hasOwnProperty.call(e, "__esModule")) return e;
  var n = e.default;
  if (typeof n == "function") {
    var t = function r() {
      var o = false;
      try {
        o = this instanceof r;
      } catch {
      }
      return o ? Reflect.construct(n, arguments, this.constructor) : n.apply(this, arguments);
    };
    t.prototype = n.prototype;
  } else t = {};
  return Object.defineProperty(t, "__esModule", { value: true }), Object.keys(e).forEach(function(r) {
    var o = Object.getOwnPropertyDescriptor(e, r);
    Object.defineProperty(t, r, o.get ? o : {
      enumerable: true,
      get: function() {
        return e[r];
      }
    });
  }), t;
}
var N = {};
var D = {};
var j = {};
var U = {};
var X;
function _e() {
  if (X) return U;
  X = 1;
  const o = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".split("");
  return U.encode = function(f) {
    if (0 <= f && f < o.length)
      return o[f];
    throw new TypeError("Must be between 0 and 63: " + f);
  }, U;
}
var Y;
function ae() {
  if (Y) return j;
  Y = 1;
  const o = _e(), f = 5, m = 1 << f, b = m - 1, p2 = m;
  function y(l) {
    return l < 0 ? (-l << 1) + 1 : (l << 1) + 0;
  }
  return j.encode = function(n) {
    let i = "", u, d2 = y(n);
    do
      u = d2 & b, d2 >>>= f, d2 > 0 && (u |= p2), i += o.encode(u);
    while (d2 > 0);
    return i;
  }, j;
}
var O = {};
var we = {};
var Ce = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
  __proto__: null,
  default: we
}, Symbol.toStringTag, { value: "Module" }));
var Se = /* @__PURE__ */ c(Ce);
var z;
var Z;
function ye() {
  return Z || (Z = 1, z = typeof URL == "function" ? URL : Se.URL), z;
}
var H;
function W() {
  if (H) return O;
  H = 1;
  const o = ye();
  function f(a, g, w) {
    if (g in a)
      return a[g];
    if (arguments.length === 3)
      return w;
    throw new Error('"' + g + '" is a required argument.');
  }
  O.getArg = f;
  const m = (function() {
    return !("__proto__" in /* @__PURE__ */ Object.create(null));
  })();
  function b(a) {
    return a;
  }
  function p2(a) {
    return l(a) ? "$" + a : a;
  }
  O.toSetString = m ? b : p2;
  function y(a) {
    return l(a) ? a.slice(1) : a;
  }
  O.fromSetString = m ? b : y;
  function l(a) {
    if (!a)
      return false;
    const g = a.length;
    if (g < 9 || a.charCodeAt(g - 1) !== 95 || a.charCodeAt(g - 2) !== 95 || a.charCodeAt(g - 3) !== 111 || a.charCodeAt(g - 4) !== 116 || a.charCodeAt(g - 5) !== 111 || a.charCodeAt(g - 6) !== 114 || a.charCodeAt(g - 7) !== 112 || a.charCodeAt(g - 8) !== 95 || a.charCodeAt(g - 9) !== 95)
      return false;
    for (let w = g - 10; w >= 0; w--)
      if (a.charCodeAt(w) !== 36)
        return false;
    return true;
  }
  function n(a, g) {
    return a === g ? 0 : a === null ? 1 : g === null ? -1 : a > g ? 1 : -1;
  }
  function i(a, g) {
    let w = a.generatedLine - g.generatedLine;
    return w !== 0 || (w = a.generatedColumn - g.generatedColumn, w !== 0) || (w = n(a.source, g.source), w !== 0) || (w = a.originalLine - g.originalLine, w !== 0) || (w = a.originalColumn - g.originalColumn, w !== 0) ? w : n(a.name, g.name);
  }
  O.compareByGeneratedPositionsInflated = i;
  function u(a) {
    return JSON.parse(a.replace(/^\)]}'[^\n]*\n/, ""));
  }
  O.parseSourceMapInput = u;
  const d2 = "http:", C = `${d2}//host`;
  function r(a) {
    return (g) => {
      const w = h(g), E = c2(g), v = new o(g, E);
      a(v);
      const M = v.toString();
      return w === "absolute" ? M : w === "scheme-relative" ? M.slice(d2.length) : w === "path-absolute" ? M.slice(C.length) : _(E, M);
    };
  }
  function e(a, g) {
    return new o(a, g).toString();
  }
  function s2(a, g) {
    let w = 0;
    do {
      const E = a + w++;
      if (g.indexOf(E) === -1) return E;
    } while (true);
  }
  function c2(a) {
    const g = a.split("..").length - 1, w = s2("p", a);
    let E = `${C}/`;
    for (let v = 0; v < g; v++)
      E += `${w}/`;
    return E;
  }
  const t = /^[A-Za-z0-9\+\-\.]+:/;
  function h(a) {
    return a[0] === "/" ? a[1] === "/" ? "scheme-relative" : "path-absolute" : t.test(a) ? "absolute" : "path-relative";
  }
  function _(a, g) {
    typeof a == "string" && (a = new o(a)), typeof g == "string" && (g = new o(g));
    const w = g.pathname.split("/"), E = a.pathname.split("/");
    for (E.length > 0 && !E[E.length - 1] && E.pop(); w.length > 0 && E.length > 0 && w[0] === E[0]; )
      w.shift(), E.shift();
    return E.map(() => "..").concat(w).join("/") + g.search + g.hash;
  }
  const S = r((a) => {
    a.pathname = a.pathname.replace(/\/?$/, "/");
  }), A = r((a) => {
    a.href = new o(".", a.toString()).toString();
  }), L = r((a) => {
  });
  O.normalize = L;
  function x(a, g) {
    const w = h(g), E = h(a);
    if (a = S(a), w === "absolute")
      return e(g, void 0);
    if (E === "absolute")
      return e(g, a);
    if (w === "scheme-relative")
      return L(g);
    if (E === "scheme-relative")
      return e(g, e(a, C)).slice(
        d2.length
      );
    if (w === "path-absolute")
      return L(g);
    if (E === "path-absolute")
      return e(g, e(a, C)).slice(
        C.length
      );
    const v = c2(g + a), M = e(g, e(a, v));
    return _(v, M);
  }
  O.join = x;
  function G(a, g) {
    const w = I(a, g);
    return typeof w == "string" ? w : L(g);
  }
  O.relative = G;
  function I(a, g) {
    if (h(a) !== h(g))
      return null;
    const E = c2(a + g), v = new o(a, E), M = new o(g, E);
    try {
      new o("", M.toString());
    } catch {
      return null;
    }
    return M.protocol !== v.protocol || M.user !== v.user || M.password !== v.password || M.hostname !== v.hostname || M.port !== v.port ? null : _(v, M);
  }
  function de(a, g, w) {
    a && h(g) === "path-absolute" && (g = g.replace(/^\//, ""));
    let E = L(g || "");
    return a && (E = x(a, E)), w && (E = x(A(w), E)), E;
  }
  return O.computeSourceURL = de, O;
}
var k = {};
var ee;
function fe() {
  if (ee) return k;
  ee = 1;
  class o {
    constructor() {
      this._array = [], this._set = /* @__PURE__ */ new Map();
    }
    /**
     * Static method for creating ArraySet instances from an existing array.
     */
    static fromArray(m, b) {
      const p2 = new o();
      for (let y = 0, l = m.length; y < l; y++)
        p2.add(m[y], b);
      return p2;
    }
    /**
     * Return how many unique items are in this ArraySet. If duplicates have been
     * added, than those do not count towards the size.
     *
     * @returns Number
     */
    size() {
      return this._set.size;
    }
    /**
     * Add the given string to this set.
     *
     * @param String aStr
     */
    add(m, b) {
      const p2 = this.has(m), y = this._array.length;
      (!p2 || b) && this._array.push(m), p2 || this._set.set(m, y);
    }
    /**
     * Is the given string a member of this set?
     *
     * @param String aStr
     */
    has(m) {
      return this._set.has(m);
    }
    /**
     * What is the index of the given string in the array?
     *
     * @param String aStr
     */
    indexOf(m) {
      const b = this._set.get(m);
      if (b >= 0)
        return b;
      throw new Error('"' + m + '" is not in the set.');
    }
    /**
     * What is the element at the given index?
     *
     * @param Number aIdx
     */
    at(m) {
      if (m >= 0 && m < this._array.length)
        return this._array[m];
      throw new Error("No element indexed by " + m);
    }
    /**
     * Returns the array representation of this set (which has the proper indices
     * indicated by indexOf). Note that this is a copy of the internal array used
     * for storing the members so that no one can mess with internal state.
     */
    toArray() {
      return this._array.slice();
    }
  }
  return k.ArraySet = o, k;
}
var $ = {};
var ne;
function be() {
  if (ne) return $;
  ne = 1;
  const o = W();
  function f(b, p2) {
    const y = b.generatedLine, l = p2.generatedLine, n = b.generatedColumn, i = p2.generatedColumn;
    return l > y || l == y && i >= n || o.compareByGeneratedPositionsInflated(b, p2) <= 0;
  }
  class m {
    constructor() {
      this._array = [], this._sorted = true, this._last = { generatedLine: -1, generatedColumn: 0 };
    }
    /**
     * Iterate through internal items. This method takes the same arguments that
     * `Array.prototype.forEach` takes.
     *
     * NOTE: The order of the mappings is NOT guaranteed.
     */
    unsortedForEach(p2, y) {
      this._array.forEach(p2, y);
    }
    /**
     * Add the given source mapping.
     *
     * @param Object aMapping
     */
    add(p2) {
      f(this._last, p2) ? (this._last = p2, this._array.push(p2)) : (this._sorted = false, this._array.push(p2));
    }
    /**
     * Returns the flat, sorted array of mappings. The mappings are sorted by
     * generated position.
     *
     * WARNING: This method returns internal data without copying, for
     * performance. The return value must NOT be mutated, and should be treated as
     * an immutable borrow. If you want to take ownership, you must make your own
     * copy.
     */
    toArray() {
      return this._sorted || (this._array.sort(o.compareByGeneratedPositionsInflated), this._sorted = true), this._array;
    }
  }
  return $.MappingList = m, $;
}
var te;
function he() {
  if (te) return D;
  te = 1;
  const o = ae(), f = W(), m = fe().ArraySet, b = be().MappingList;
  class p2 {
    constructor(l) {
      l || (l = {}), this._file = f.getArg(l, "file", null), this._sourceRoot = f.getArg(l, "sourceRoot", null), this._skipValidation = f.getArg(l, "skipValidation", false), this._sources = new m(), this._names = new m(), this._mappings = new b(), this._sourcesContents = null;
    }
    /**
     * Creates a new SourceMapGenerator based on a SourceMapConsumer
     *
     * @param aSourceMapConsumer The SourceMap.
     */
    static fromSourceMap(l) {
      const n = l.sourceRoot, i = new p2({
        file: l.file,
        sourceRoot: n
      });
      return l.eachMapping(function(u) {
        const d2 = {
          generated: {
            line: u.generatedLine,
            column: u.generatedColumn
          }
        };
        u.source != null && (d2.source = u.source, n != null && (d2.source = f.relative(n, d2.source)), d2.original = {
          line: u.originalLine,
          column: u.originalColumn
        }, u.name != null && (d2.name = u.name)), i.addMapping(d2);
      }), l.sources.forEach(function(u) {
        let d2 = u;
        n != null && (d2 = f.relative(n, u)), i._sources.has(d2) || i._sources.add(d2);
        const C = l.sourceContentFor(u);
        C != null && i.setSourceContent(u, C);
      }), i;
    }
    /**
     * Add a single mapping from original source line and column to the generated
     * source's line and column for this source map being created. The mapping
     * object should have the following properties:
     *
     *   - generated: An object with the generated line and column positions.
     *   - original: An object with the original line and column positions.
     *   - source: The original source file (relative to the sourceRoot).
     *   - name: An optional original token name for this mapping.
     */
    addMapping(l) {
      const n = f.getArg(l, "generated"), i = f.getArg(l, "original", null);
      let u = f.getArg(l, "source", null), d2 = f.getArg(l, "name", null);
      this._skipValidation || this._validateMapping(n, i, u, d2), u != null && (u = String(u), this._sources.has(u) || this._sources.add(u)), d2 != null && (d2 = String(d2), this._names.has(d2) || this._names.add(d2)), this._mappings.add({
        generatedLine: n.line,
        generatedColumn: n.column,
        originalLine: i && i.line,
        originalColumn: i && i.column,
        source: u,
        name: d2
      });
    }
    /**
     * Set the source content for a source file.
     */
    setSourceContent(l, n) {
      let i = l;
      this._sourceRoot != null && (i = f.relative(this._sourceRoot, i)), n != null ? (this._sourcesContents || (this._sourcesContents = /* @__PURE__ */ Object.create(null)), this._sourcesContents[f.toSetString(i)] = n) : this._sourcesContents && (delete this._sourcesContents[f.toSetString(i)], Object.keys(this._sourcesContents).length === 0 && (this._sourcesContents = null));
    }
    /**
     * Applies the mappings of a sub-source-map for a specific source file to the
     * source map being generated. Each mapping to the supplied source file is
     * rewritten using the supplied source map. Note: The resolution for the
     * resulting mappings is the minimium of this map and the supplied map.
     *
     * @param aSourceMapConsumer The source map to be applied.
     * @param aSourceFile Optional. The filename of the source file.
     *        If omitted, SourceMapConsumer's file property will be used.
     * @param aSourceMapPath Optional. The dirname of the path to the source map
     *        to be applied. If relative, it is relative to the SourceMapConsumer.
     *        This parameter is needed when the two source maps aren't in the same
     *        directory, and the source map to be applied contains relative source
     *        paths. If so, those relative source paths need to be rewritten
     *        relative to the SourceMapGenerator.
     */
    applySourceMap(l, n, i) {
      let u = n;
      if (n == null) {
        if (l.file == null)
          throw new Error(
            `SourceMapGenerator.prototype.applySourceMap requires either an explicit source file, or the source map's "file" property. Both were omitted.`
          );
        u = l.file;
      }
      const d2 = this._sourceRoot;
      d2 != null && (u = f.relative(d2, u));
      const C = this._mappings.toArray().length > 0 ? new m() : this._sources, r = new m();
      this._mappings.unsortedForEach(function(e) {
        if (e.source === u && e.originalLine != null) {
          const t = l.originalPositionFor({
            line: e.originalLine,
            column: e.originalColumn
          });
          t.source != null && (e.source = t.source, i != null && (e.source = f.join(i, e.source)), d2 != null && (e.source = f.relative(d2, e.source)), e.originalLine = t.line, e.originalColumn = t.column, t.name != null && (e.name = t.name));
        }
        const s2 = e.source;
        s2 != null && !C.has(s2) && C.add(s2);
        const c2 = e.name;
        c2 != null && !r.has(c2) && r.add(c2);
      }, this), this._sources = C, this._names = r, l.sources.forEach(function(e) {
        const s2 = l.sourceContentFor(e);
        s2 != null && (i != null && (e = f.join(i, e)), d2 != null && (e = f.relative(d2, e)), this.setSourceContent(e, s2));
      }, this);
    }
    /**
     * A mapping can have one of the three levels of data:
     *
     *   1. Just the generated position.
     *   2. The Generated position, original position, and original source.
     *   3. Generated and original position, original source, as well as a name
     *      token.
     *
     * To maintain consistency, we validate that any new mapping being added falls
     * in to one of these categories.
     */
    _validateMapping(l, n, i, u) {
      if (n && typeof n.line != "number" && typeof n.column != "number")
        throw new Error(
          "original.line and original.column are not numbers -- you probably meant to omit the original mapping entirely and only map the generated position. If so, pass null for the original mapping instead of an object with empty or null values."
        );
      if (!(l && "line" in l && "column" in l && l.line > 0 && l.column >= 0 && !n && !i && !u)) {
        if (!(l && "line" in l && "column" in l && n && "line" in n && "column" in n && l.line > 0 && l.column >= 0 && n.line > 0 && n.column >= 0 && i)) throw new Error(
          "Invalid mapping: " + JSON.stringify({
            generated: l,
            source: i,
            original: n,
            name: u
          })
        );
      }
    }
    /**
     * Serialize the accumulated mappings in to the stream of base 64 VLQs
     * specified by the source map format.
     */
    _serializeMappings() {
      let l = 0, n = 1, i = 0, u = 0, d2 = 0, C = 0, r = "", e, s2, c2, t;
      const h = this._mappings.toArray();
      for (let _ = 0, S = h.length; _ < S; _++) {
        if (s2 = h[_], e = "", s2.generatedLine !== n)
          for (l = 0; s2.generatedLine !== n; )
            e += ";", n++;
        else if (_ > 0) {
          if (!f.compareByGeneratedPositionsInflated(s2, h[_ - 1]))
            continue;
          e += ",";
        }
        e += o.encode(
          s2.generatedColumn - l
        ), l = s2.generatedColumn, s2.source != null && (t = this._sources.indexOf(s2.source), e += o.encode(t - C), C = t, e += o.encode(
          s2.originalLine - 1 - u
        ), u = s2.originalLine - 1, e += o.encode(
          s2.originalColumn - i
        ), i = s2.originalColumn, s2.name != null && (c2 = this._names.indexOf(s2.name), e += o.encode(c2 - d2), d2 = c2)), r += e;
      }
      return r;
    }
    _generateSourcesContent(l, n) {
      return l.map(function(i) {
        if (!this._sourcesContents)
          return null;
        n != null && (i = f.relative(n, i));
        const u = f.toSetString(i);
        return Object.prototype.hasOwnProperty.call(this._sourcesContents, u) ? this._sourcesContents[u] : null;
      }, this);
    }
    /**
     * Externalize the source map.
     */
    toJSON() {
      const l = {
        version: this._version,
        sources: this._sources.toArray(),
        names: this._names.toArray(),
        mappings: this._serializeMappings()
      };
      return this._file != null && (l.file = this._file), this._sourceRoot != null && (l.sourceRoot = this._sourceRoot), this._sourcesContents && (l.sourcesContent = this._generateSourcesContent(
        l.sources,
        l.sourceRoot
      )), l;
    }
    /**
     * Render the source map being generated to a string.
     */
    toString() {
      return JSON.stringify(this.toJSON());
    }
  }
  return p2.prototype._version = 3, D.SourceMapGenerator = p2, D;
}
var P = {};
var F = {};
var re;
function Ee() {
  return re || (re = 1, (function(o) {
    o.GREATEST_LOWER_BOUND = 1, o.LEAST_UPPER_BOUND = 2;
    function f(m, b, p2, y, l, n) {
      const i = Math.floor((b - m) / 2) + m, u = l(p2, y[i], true);
      return u === 0 ? i : u > 0 ? b - i > 1 ? f(i, b, p2, y, l, n) : n === o.LEAST_UPPER_BOUND ? b < y.length ? b : -1 : i : i - m > 1 ? f(m, i, p2, y, l, n) : n == o.LEAST_UPPER_BOUND ? i : m < 0 ? -1 : m;
    }
    o.search = function(b, p2, y, l) {
      if (p2.length === 0)
        return -1;
      let n = f(
        -1,
        p2.length,
        b,
        p2,
        y,
        l || o.GREATEST_LOWER_BOUND
      );
      if (n < 0)
        return -1;
      for (; n - 1 >= 0 && y(p2[n], p2[n - 1], true) === 0; )
        --n;
      return n;
    };
  })(F)), F;
}
var q = { exports: {} };
var oe;
function me() {
  if (oe) return q.exports;
  oe = 1;
  let o = null;
  return q.exports = function() {
    if (typeof o == "string")
      return fetch(o).then((m) => m.arrayBuffer());
    if (o instanceof ArrayBuffer)
      return Promise.resolve(o);
    throw new Error(
      "You must provide the string URL or ArrayBuffer contents of lib/mappings.wasm by calling SourceMapConsumer.initialize({ 'lib/mappings.wasm': ... }) before using SourceMapConsumer"
    );
  }, q.exports.initialize = (f) => {
    o = f;
  }, q.exports;
}
var V;
var se;
function Le() {
  if (se) return V;
  se = 1;
  const o = me();
  function f() {
    this.generatedLine = 0, this.generatedColumn = 0, this.lastGeneratedColumn = null, this.source = null, this.originalLine = null, this.originalColumn = null, this.name = null;
  }
  let m = null;
  return V = function() {
    if (m)
      return m;
    const p2 = [];
    return m = o().then((y) => WebAssembly.instantiate(y, {
      env: {
        mapping_callback(l, n, i, u, d2, C, r, e, s2, c2) {
          const t = new f();
          t.generatedLine = l + 1, t.generatedColumn = n, i && (t.lastGeneratedColumn = u - 1), d2 && (t.source = C, t.originalLine = r + 1, t.originalColumn = e, s2 && (t.name = c2)), p2[p2.length - 1](t);
        },
        start_all_generated_locations_for() {
          console.time("all_generated_locations_for");
        },
        end_all_generated_locations_for() {
          console.timeEnd("all_generated_locations_for");
        },
        start_compute_column_spans() {
          console.time("compute_column_spans");
        },
        end_compute_column_spans() {
          console.timeEnd("compute_column_spans");
        },
        start_generated_location_for() {
          console.time("generated_location_for");
        },
        end_generated_location_for() {
          console.timeEnd("generated_location_for");
        },
        start_original_location_for() {
          console.time("original_location_for");
        },
        end_original_location_for() {
          console.timeEnd("original_location_for");
        },
        start_parse_mappings() {
          console.time("parse_mappings");
        },
        end_parse_mappings() {
          console.timeEnd("parse_mappings");
        },
        start_sort_by_generated_location() {
          console.time("sort_by_generated_location");
        },
        end_sort_by_generated_location() {
          console.timeEnd("sort_by_generated_location");
        },
        start_sort_by_original_location() {
          console.time("sort_by_original_location");
        },
        end_sort_by_original_location() {
          console.timeEnd("sort_by_original_location");
        }
      }
    })).then((y) => ({
      exports: y.instance.exports,
      withMappingCallback: (l, n) => {
        p2.push(l);
        try {
          n();
        } finally {
          p2.pop();
        }
      }
    })).then(null, (y) => {
      throw m = null, y;
    }), m;
  }, V;
}
var ie;
function Ae() {
  if (ie) return P;
  ie = 1;
  const o = W(), f = Ee(), m = fe().ArraySet;
  ae();
  const b = me(), p2 = Le(), y = /* @__PURE__ */ Symbol("smcInternal");
  class l {
    constructor(r, e) {
      return r == y ? Promise.resolve(this) : u(r, e);
    }
    static initialize(r) {
      b.initialize(r["lib/mappings.wasm"]);
    }
    static fromSourceMap(r, e) {
      return d2(r, e);
    }
    /**
     * Construct a new `SourceMapConsumer` from `rawSourceMap` and `sourceMapUrl`
     * (see the `SourceMapConsumer` constructor for details. Then, invoke the `async
     * function f(SourceMapConsumer) -> T` with the newly constructed consumer, wait
     * for `f` to complete, call `destroy` on the consumer, and return `f`'s return
     * value.
     *
     * You must not use the consumer after `f` completes!
     *
     * By using `with`, you do not have to remember to manually call `destroy` on
     * the consumer, since it will be called automatically once `f` completes.
     *
     * ```js
     * const xSquared = await SourceMapConsumer.with(
     *   myRawSourceMap,
     *   null,
     *   async function (consumer) {
     *     // Use `consumer` inside here and don't worry about remembering
     *     // to call `destroy`.
     *
     *     const x = await whatever(consumer);
     *     return x * x;
     *   }
     * );
     *
     * // You may not use that `consumer` anymore out here; it has
     * // been destroyed. But you can use `xSquared`.
     * console.log(xSquared);
     * ```
     */
    static async with(r, e, s2) {
      const c2 = await new l(r, e);
      try {
        return await s2(c2);
      } finally {
        c2.destroy();
      }
    }
    /**
     * Iterate over each mapping between an original source/line/column and a
     * generated line/column in this source map.
     *
     * @param Function aCallback
     *        The function that is called with each mapping.
     * @param Object aContext
     *        Optional. If specified, this object will be the value of `this` every
     *        time that `aCallback` is called.
     * @param aOrder
     *        Either `SourceMapConsumer.GENERATED_ORDER` or
     *        `SourceMapConsumer.ORIGINAL_ORDER`. Specifies whether you want to
     *        iterate over the mappings sorted by the generated file's line/column
     *        order or the original's source/line/column order, respectively. Defaults to
     *        `SourceMapConsumer.GENERATED_ORDER`.
     */
    eachMapping(r, e, s2) {
      throw new Error("Subclasses must implement eachMapping");
    }
    /**
     * Returns all generated line and column information for the original source,
     * line, and column provided. If no column is provided, returns all mappings
     * corresponding to a either the line we are searching for or the next
     * closest line that has any mappings. Otherwise, returns all mappings
     * corresponding to the given line and either the column we are searching for
     * or the next closest column that has any offsets.
     *
     * The only argument is an object with the following properties:
     *
     *   - source: The filename of the original source.
     *   - line: The line number in the original source.  The line number is 1-based.
     *   - column: Optional. the column number in the original source.
     *    The column number is 0-based.
     *
     * and an array of objects is returned, each with the following properties:
     *
     *   - line: The line number in the generated source, or null.  The
     *    line number is 1-based.
     *   - column: The column number in the generated source, or null.
     *    The column number is 0-based.
     */
    allGeneratedPositionsFor(r) {
      throw new Error("Subclasses must implement allGeneratedPositionsFor");
    }
    destroy() {
      throw new Error("Subclasses must implement destroy");
    }
  }
  l.prototype._version = 3, l.GENERATED_ORDER = 1, l.ORIGINAL_ORDER = 2, l.GREATEST_LOWER_BOUND = 1, l.LEAST_UPPER_BOUND = 2, P.SourceMapConsumer = l;
  class n extends l {
    constructor(r, e) {
      return super(y).then((s2) => {
        let c2 = r;
        typeof r == "string" && (c2 = o.parseSourceMapInput(r));
        const t = o.getArg(c2, "version"), h = o.getArg(c2, "sources").map(String), _ = o.getArg(c2, "names", []), S = o.getArg(c2, "sourceRoot", null), A = o.getArg(c2, "sourcesContent", null), L = o.getArg(c2, "mappings"), x = o.getArg(c2, "file", null), G = o.getArg(
          c2,
          "x_google_ignoreList",
          null
        );
        if (t != s2._version)
          throw new Error("Unsupported version: " + t);
        return s2._sourceLookupCache = /* @__PURE__ */ new Map(), s2._names = m.fromArray(_.map(String), true), s2._sources = m.fromArray(h, true), s2._absoluteSources = m.fromArray(
          s2._sources.toArray().map(function(I) {
            return o.computeSourceURL(S, I, e);
          }),
          true
        ), s2.sourceRoot = S, s2.sourcesContent = A, s2._mappings = L, s2._sourceMapURL = e, s2.file = x, s2.x_google_ignoreList = G, s2._computedColumnSpans = false, s2._mappingsPtr = 0, s2._wasm = null, p2().then((I) => (s2._wasm = I, s2));
      });
    }
    /**
     * Utility function to find the index of a source.  Returns -1 if not
     * found.
     */
    _findSourceIndex(r) {
      const e = this._sourceLookupCache.get(r);
      if (typeof e == "number")
        return e;
      const s2 = o.computeSourceURL(
        null,
        r,
        this._sourceMapURL
      );
      if (this._absoluteSources.has(s2)) {
        const t = this._absoluteSources.indexOf(s2);
        return this._sourceLookupCache.set(r, t), t;
      }
      const c2 = o.computeSourceURL(
        this.sourceRoot,
        r,
        this._sourceMapURL
      );
      if (this._absoluteSources.has(c2)) {
        const t = this._absoluteSources.indexOf(c2);
        return this._sourceLookupCache.set(r, t), t;
      }
      return -1;
    }
    /**
     * Create a BasicSourceMapConsumer from a SourceMapGenerator.
     *
     * @param SourceMapGenerator aSourceMap
     *        The source map that will be consumed.
     * @param String aSourceMapURL
     *        The URL at which the source map can be found (optional)
     * @returns BasicSourceMapConsumer
     */
    static fromSourceMap(r, e) {
      return new n(r.toString());
    }
    get sources() {
      return this._absoluteSources.toArray();
    }
    _getMappingsPtr() {
      return this._mappingsPtr === 0 && this._parseMappings(), this._mappingsPtr;
    }
    /**
     * Parse the mappings in a string in to a data structure which we can easily
     * query (the ordered arrays in the `this.__generatedMappings` and
     * `this.__originalMappings` properties).
     */
    _parseMappings() {
      const r = this._mappings, e = r.length, s2 = this._wasm.exports.allocate_mappings(e) >>> 0, c2 = new Uint8Array(
        this._wasm.exports.memory.buffer,
        s2,
        e
      );
      for (let h = 0; h < e; h++)
        c2[h] = r.charCodeAt(h);
      const t = this._wasm.exports.parse_mappings(s2);
      if (!t) {
        const h = this._wasm.exports.get_last_error();
        let _ = `Error parsing mappings (code ${h}): `;
        switch (h) {
          case 1:
            _ += "the mappings contained a negative line, column, source index, or name index";
            break;
          case 2:
            _ += "the mappings contained a number larger than 2**32";
            break;
          case 3:
            _ += "reached EOF while in the middle of parsing a VLQ";
            break;
          case 4:
            _ += "invalid base 64 character while parsing a VLQ";
            break;
          default:
            _ += "unknown error code";
            break;
        }
        throw new Error(_);
      }
      this._mappingsPtr = t;
    }
    eachMapping(r, e, s2) {
      const c2 = e || null, t = s2 || l.GENERATED_ORDER;
      this._wasm.withMappingCallback(
        (h) => {
          h.source !== null && (h.source = this._absoluteSources.at(h.source), h.name !== null && (h.name = this._names.at(h.name))), this._computedColumnSpans && h.lastGeneratedColumn === null && (h.lastGeneratedColumn = 1 / 0), r.call(c2, h);
        },
        () => {
          switch (t) {
            case l.GENERATED_ORDER:
              this._wasm.exports.by_generated_location(this._getMappingsPtr());
              break;
            case l.ORIGINAL_ORDER:
              this._wasm.exports.by_original_location(this._getMappingsPtr());
              break;
            default:
              throw new Error("Unknown order of iteration.");
          }
        }
      );
    }
    allGeneratedPositionsFor(r) {
      let e = o.getArg(r, "source");
      const s2 = o.getArg(r, "line"), c2 = r.column || 0;
      if (e = this._findSourceIndex(e), e < 0)
        return [];
      if (s2 < 1)
        throw new Error("Line numbers must be >= 1");
      if (c2 < 0)
        throw new Error("Column numbers must be >= 0");
      const t = [];
      return this._wasm.withMappingCallback(
        (h) => {
          let _ = h.lastGeneratedColumn;
          this._computedColumnSpans && _ === null && (_ = 1 / 0), t.push({
            line: h.generatedLine,
            column: h.generatedColumn,
            lastColumn: _
          });
        },
        () => {
          this._wasm.exports.all_generated_locations_for(
            this._getMappingsPtr(),
            e,
            s2 - 1,
            "column" in r,
            c2
          );
        }
      ), t;
    }
    destroy() {
      this._mappingsPtr !== 0 && (this._wasm.exports.free_mappings(this._mappingsPtr), this._mappingsPtr = 0);
    }
    /**
     * Compute the last column for each generated mapping. The last column is
     * inclusive.
     */
    computeColumnSpans() {
      this._computedColumnSpans || (this._wasm.exports.compute_column_spans(this._getMappingsPtr()), this._computedColumnSpans = true);
    }
    /**
     * Returns the original source, line, and column information for the generated
     * source's line and column positions provided. The only argument is an object
     * with the following properties:
     *
     *   - line: The line number in the generated source.  The line number
     *     is 1-based.
     *   - column: The column number in the generated source.  The column
     *     number is 0-based.
     *   - bias: Either 'SourceMapConsumer.GREATEST_LOWER_BOUND' or
     *     'SourceMapConsumer.LEAST_UPPER_BOUND'. Specifies whether to return the
     *     closest element that is smaller than or greater than the one we are
     *     searching for, respectively, if the exact element cannot be found.
     *     Defaults to 'SourceMapConsumer.GREATEST_LOWER_BOUND'.
     *
     * and an object is returned with the following properties:
     *
     *   - source: The original source file, or null.
     *   - line: The line number in the original source, or null.  The
     *     line number is 1-based.
     *   - column: The column number in the original source, or null.  The
     *     column number is 0-based.
     *   - name: The original identifier, or null.
     */
    originalPositionFor(r) {
      const e = {
        generatedLine: o.getArg(r, "line"),
        generatedColumn: o.getArg(r, "column")
      };
      if (e.generatedLine < 1)
        throw new Error("Line numbers must be >= 1");
      if (e.generatedColumn < 0)
        throw new Error("Column numbers must be >= 0");
      let s2 = o.getArg(
        r,
        "bias",
        l.GREATEST_LOWER_BOUND
      );
      s2 == null && (s2 = l.GREATEST_LOWER_BOUND);
      let c2;
      if (this._wasm.withMappingCallback(
        (t) => c2 = t,
        () => {
          this._wasm.exports.original_location_for(
            this._getMappingsPtr(),
            e.generatedLine - 1,
            e.generatedColumn,
            s2
          );
        }
      ), c2 && c2.generatedLine === e.generatedLine) {
        let t = o.getArg(c2, "source", null);
        t !== null && (t = this._absoluteSources.at(t));
        let h = o.getArg(c2, "name", null);
        return h !== null && (h = this._names.at(h)), {
          source: t,
          line: o.getArg(c2, "originalLine", null),
          column: o.getArg(c2, "originalColumn", null),
          name: h
        };
      }
      return {
        source: null,
        line: null,
        column: null,
        name: null
      };
    }
    /**
     * Return true if we have the source content for every source in the source
     * map, false otherwise.
     */
    hasContentsOfAllSources() {
      return this.sourcesContent ? this.sourcesContent.length >= this._sources.size() && !this.sourcesContent.some(function(r) {
        return r == null;
      }) : false;
    }
    /**
     * Returns the original source content. The only argument is the url of the
     * original source file. Returns null if no original source content is
     * available.
     */
    sourceContentFor(r, e) {
      if (!this.sourcesContent)
        return null;
      const s2 = this._findSourceIndex(r);
      if (s2 >= 0)
        return this.sourcesContent[s2];
      if (e)
        return null;
      throw new Error('"' + r + '" is not in the SourceMap.');
    }
    /**
     * Returns the generated line and column information for the original source,
     * line, and column positions provided. The only argument is an object with
     * the following properties:
     *
     *   - source: The filename of the original source.
     *   - line: The line number in the original source.  The line number
     *     is 1-based.
     *   - column: The column number in the original source.  The column
     *     number is 0-based.
     *   - bias: Either 'SourceMapConsumer.GREATEST_LOWER_BOUND' or
     *     'SourceMapConsumer.LEAST_UPPER_BOUND'. Specifies whether to return the
     *     closest element that is smaller than or greater than the one we are
     *     searching for, respectively, if the exact element cannot be found.
     *     Defaults to 'SourceMapConsumer.GREATEST_LOWER_BOUND'.
     *
     * and an object is returned with the following properties:
     *
     *   - line: The line number in the generated source, or null.  The
     *     line number is 1-based.
     *   - column: The column number in the generated source, or null.
     *     The column number is 0-based.
     */
    generatedPositionFor(r) {
      let e = o.getArg(r, "source");
      if (e = this._findSourceIndex(e), e < 0)
        return {
          line: null,
          column: null,
          lastColumn: null
        };
      const s2 = {
        source: e,
        originalLine: o.getArg(r, "line"),
        originalColumn: o.getArg(r, "column")
      };
      if (s2.originalLine < 1)
        throw new Error("Line numbers must be >= 1");
      if (s2.originalColumn < 0)
        throw new Error("Column numbers must be >= 0");
      let c2 = o.getArg(
        r,
        "bias",
        l.GREATEST_LOWER_BOUND
      );
      c2 == null && (c2 = l.GREATEST_LOWER_BOUND);
      let t;
      if (this._wasm.withMappingCallback(
        (h) => t = h,
        () => {
          this._wasm.exports.generated_location_for(
            this._getMappingsPtr(),
            s2.source,
            s2.originalLine - 1,
            s2.originalColumn,
            c2
          );
        }
      ), t && t.source === s2.source) {
        let h = t.lastGeneratedColumn;
        return this._computedColumnSpans && h === null && (h = 1 / 0), {
          line: o.getArg(t, "generatedLine", null),
          column: o.getArg(t, "generatedColumn", null),
          lastColumn: h
        };
      }
      return {
        line: null,
        column: null,
        lastColumn: null
      };
    }
  }
  n.prototype.consumer = l, P.BasicSourceMapConsumer = n;
  class i extends l {
    constructor(r, e) {
      return super(y).then((s2) => {
        let c2 = r;
        typeof r == "string" && (c2 = o.parseSourceMapInput(r));
        const t = o.getArg(c2, "version"), h = o.getArg(c2, "sections");
        if (t != s2._version)
          throw new Error("Unsupported version: " + t);
        let _ = {
          line: -1,
          column: 0
        };
        return Promise.all(
          h.map((S) => {
            if (S.url)
              throw new Error(
                "Support for url field in sections not implemented."
              );
            const A = o.getArg(S, "offset"), L = o.getArg(A, "line"), x = o.getArg(A, "column");
            if (L < _.line || L === _.line && x < _.column)
              throw new Error(
                "Section offsets must be ordered and non-overlapping."
              );
            return _ = A, new l(
              o.getArg(S, "map"),
              e
            ).then((I) => ({
              generatedOffset: {
                // The offset fields are 0-based, but we use 1-based indices when
                // encoding/decoding from VLQ.
                generatedLine: L + 1,
                generatedColumn: x + 1
              },
              consumer: I
            }));
          })
        ).then((S) => (s2._sections = S, s2));
      });
    }
    /**
     * The list of original sources.
     */
    get sources() {
      const r = [];
      for (let e = 0; e < this._sections.length; e++)
        for (let s2 = 0; s2 < this._sections[e].consumer.sources.length; s2++)
          r.push(this._sections[e].consumer.sources[s2]);
      return r;
    }
    /**
     * Returns the original source, line, and column information for the generated
     * source's line and column positions provided. The only argument is an object
     * with the following properties:
     *
     *   - line: The line number in the generated source.  The line number
     *     is 1-based.
     *   - column: The column number in the generated source.  The column
     *     number is 0-based.
     *
     * and an object is returned with the following properties:
     *
     *   - source: The original source file, or null.
     *   - line: The line number in the original source, or null.  The
     *     line number is 1-based.
     *   - column: The column number in the original source, or null.  The
     *     column number is 0-based.
     *   - name: The original identifier, or null.
     */
    originalPositionFor(r) {
      const e = {
        generatedLine: o.getArg(r, "line"),
        generatedColumn: o.getArg(r, "column")
      }, s2 = f.search(
        e,
        this._sections,
        function(t, h) {
          const _ = t.generatedLine - h.generatedOffset.generatedLine;
          return _ || t.generatedColumn - (h.generatedOffset.generatedColumn - 1);
        }
      ), c2 = this._sections[s2];
      return c2 ? c2.consumer.originalPositionFor({
        line: e.generatedLine - (c2.generatedOffset.generatedLine - 1),
        column: e.generatedColumn - (c2.generatedOffset.generatedLine === e.generatedLine ? c2.generatedOffset.generatedColumn - 1 : 0),
        bias: r.bias
      }) : {
        source: null,
        line: null,
        column: null,
        name: null
      };
    }
    /**
     * Return true if we have the source content for every source in the source
     * map, false otherwise.
     */
    hasContentsOfAllSources() {
      return this._sections.every(function(r) {
        return r.consumer.hasContentsOfAllSources();
      });
    }
    /**
     * Returns the original source content. The only argument is the url of the
     * original source file. Returns null if no original source content is
     * available.
     */
    sourceContentFor(r, e) {
      for (let s2 = 0; s2 < this._sections.length; s2++) {
        const t = this._sections[s2].consumer.sourceContentFor(r, true);
        if (t)
          return t;
      }
      if (e)
        return null;
      throw new Error('"' + r + '" is not in the SourceMap.');
    }
    _findSectionIndex(r) {
      for (let e = 0; e < this._sections.length; e++) {
        const { consumer: s2 } = this._sections[e];
        if (s2._findSourceIndex(r) !== -1)
          return e;
      }
      return -1;
    }
    /**
     * Returns the generated line and column information for the original source,
     * line, and column positions provided. The only argument is an object with
     * the following properties:
     *
     *   - source: The filename of the original source.
     *   - line: The line number in the original source.  The line number
     *     is 1-based.
     *   - column: The column number in the original source.  The column
     *     number is 0-based.
     *
     * and an object is returned with the following properties:
     *
     *   - line: The line number in the generated source, or null.  The
     *     line number is 1-based.
     *   - column: The column number in the generated source, or null.
     *     The column number is 0-based.
     */
    generatedPositionFor(r) {
      const e = this._findSectionIndex(o.getArg(r, "source")), s2 = e >= 0 ? this._sections[e] : null, c2 = e >= 0 && e + 1 < this._sections.length ? this._sections[e + 1] : null, t = s2 && s2.consumer.generatedPositionFor(r);
      if (t && t.line !== null) {
        const h = s2.generatedOffset.generatedLine - 1, _ = s2.generatedOffset.generatedColumn - 1;
        return t.line === 1 && (t.column += _, typeof t.lastColumn == "number" && (t.lastColumn += _)), t.lastColumn === 1 / 0 && c2 && t.line === c2.generatedOffset.generatedLine && (t.lastColumn = c2.generatedOffset.generatedColumn - 2), t.line += h, t;
      }
      return {
        line: null,
        column: null,
        lastColumn: null
      };
    }
    allGeneratedPositionsFor(r) {
      const e = this._findSectionIndex(o.getArg(r, "source")), s2 = e >= 0 ? this._sections[e] : null, c2 = e >= 0 && e + 1 < this._sections.length ? this._sections[e + 1] : null;
      return s2 ? s2.consumer.allGeneratedPositionsFor(r).map((t) => {
        const h = s2.generatedOffset.generatedLine - 1, _ = s2.generatedOffset.generatedColumn - 1;
        return t.line === 1 && (t.column += _, typeof t.lastColumn == "number" && (t.lastColumn += _)), t.lastColumn === 1 / 0 && c2 && t.line === c2.generatedOffset.generatedLine && (t.lastColumn = c2.generatedOffset.generatedColumn - 2), t.line += h, t;
      }) : [];
    }
    eachMapping(r, e, s2) {
      this._sections.forEach((c2, t) => {
        const h = t + 1 < this._sections.length ? this._sections[t + 1] : null, { generatedOffset: _ } = c2, S = _.generatedLine - 1, A = _.generatedColumn - 1;
        c2.consumer.eachMapping(
          function(L) {
            L.generatedLine === 1 && (L.generatedColumn += A, typeof L.lastGeneratedColumn == "number" && (L.lastGeneratedColumn += A)), L.lastGeneratedColumn === 1 / 0 && h && L.generatedLine === h.generatedOffset.generatedLine && (L.lastGeneratedColumn = h.generatedOffset.generatedColumn - 2), L.generatedLine += S, r.call(this, L);
          },
          e,
          s2
        );
      });
    }
    computeColumnSpans() {
      for (let r = 0; r < this._sections.length; r++)
        this._sections[r].consumer.computeColumnSpans();
    }
    destroy() {
      for (let r = 0; r < this._sections.length; r++)
        this._sections[r].consumer.destroy();
    }
  }
  P.IndexedSourceMapConsumer = i;
  function u(C, r) {
    let e = C;
    typeof C == "string" && (e = o.parseSourceMapInput(C));
    const s2 = e.sections != null ? new i(e, r) : new n(e, r);
    return Promise.resolve(s2);
  }
  function d2(C, r) {
    return n.fromSourceMap(C, r);
  }
  return P;
}
var Q = {};
var le;
function ve() {
  if (le) return Q;
  le = 1;
  const o = he().SourceMapGenerator, f = W(), m = /(\r?\n)/, b = 10, p2 = "$$$isSourceNode$$$";
  class y {
    constructor(n, i, u, d2, C) {
      this.children = [], this.sourceContents = {}, this.line = n ?? null, this.column = i ?? null, this.source = u ?? null, this.name = C ?? null, this[p2] = true, d2 != null && this.add(d2);
    }
    /**
     * Creates a SourceNode from generated code and a SourceMapConsumer.
     *
     * @param aGeneratedCode The generated code
     * @param aSourceMapConsumer The SourceMap for the generated code
     * @param aRelativePath Optional. The path that relative sources in the
     *        SourceMapConsumer should be relative to.
     */
    static fromStringWithSourceMap(n, i, u) {
      const d2 = new y(), C = n.split(m);
      let r = 0;
      const e = function() {
        const S = L(), A = L() || "";
        return S + A;
        function L() {
          return r < C.length ? C[r++] : void 0;
        }
      };
      let s2 = 1, c2 = 0, t = null, h;
      return i.eachMapping(function(S) {
        if (t !== null)
          if (s2 < S.generatedLine)
            _(t, e()), s2++, c2 = 0;
          else {
            h = C[r] || "";
            const A = h.substr(
              0,
              S.generatedColumn - c2
            );
            C[r] = h.substr(
              S.generatedColumn - c2
            ), c2 = S.generatedColumn, _(t, A), t = S;
            return;
          }
        for (; s2 < S.generatedLine; )
          d2.add(e()), s2++;
        c2 < S.generatedColumn && (h = C[r] || "", d2.add(h.substr(0, S.generatedColumn)), C[r] = h.substr(
          S.generatedColumn
        ), c2 = S.generatedColumn), t = S;
      }, this), r < C.length && (t && _(t, e()), d2.add(C.splice(r).join(""))), i.sources.forEach(function(S) {
        const A = i.sourceContentFor(S);
        A != null && (u != null && (S = f.join(u, S)), d2.setSourceContent(S, A));
      }), d2;
      function _(S, A) {
        if (S === null || S.source === void 0)
          d2.add(A);
        else {
          const L = u ? f.join(u, S.source) : S.source;
          d2.add(
            new y(
              S.originalLine,
              S.originalColumn,
              L,
              A,
              S.name
            )
          );
        }
      }
    }
    /**
     * Add a chunk of generated JS to this source node.
     *
     * @param aChunk A string snippet of generated JS code, another instance of
     *        SourceNode, or an array where each member is one of those things.
     */
    add(n) {
      if (Array.isArray(n))
        n.forEach(function(i) {
          this.add(i);
        }, this);
      else if (n[p2] || typeof n == "string")
        n && this.children.push(n);
      else
        throw new TypeError(
          "Expected a SourceNode, string, or an array of SourceNodes and strings. Got " + n
        );
      return this;
    }
    /**
     * Add a chunk of generated JS to the beginning of this source node.
     *
     * @param aChunk A string snippet of generated JS code, another instance of
     *        SourceNode, or an array where each member is one of those things.
     */
    prepend(n) {
      if (Array.isArray(n))
        for (let i = n.length - 1; i >= 0; i--)
          this.prepend(n[i]);
      else if (n[p2] || typeof n == "string")
        this.children.unshift(n);
      else
        throw new TypeError(
          "Expected a SourceNode, string, or an array of SourceNodes and strings. Got " + n
        );
      return this;
    }
    /**
     * Walk over the tree of JS snippets in this node and its children. The
     * walking function is called once for each snippet of JS and is passed that
     * snippet and the its original associated source's line/column location.
     *
     * @param aFn The traversal function.
     */
    walk(n) {
      let i;
      for (let u = 0, d2 = this.children.length; u < d2; u++)
        i = this.children[u], i[p2] ? i.walk(n) : i !== "" && n(i, {
          source: this.source,
          line: this.line,
          column: this.column,
          name: this.name
        });
    }
    /**
     * Like `String.prototype.join` except for SourceNodes. Inserts `aStr` between
     * each of `this.children`.
     *
     * @param aSep The separator.
     */
    join(n) {
      let i, u;
      const d2 = this.children.length;
      if (d2 > 0) {
        for (i = [], u = 0; u < d2 - 1; u++)
          i.push(this.children[u]), i.push(n);
        i.push(this.children[u]), this.children = i;
      }
      return this;
    }
    /**
     * Call String.prototype.replace on the very right-most source snippet. Useful
     * for trimming whitespace from the end of a source node, etc.
     *
     * @param aPattern The pattern to replace.
     * @param aReplacement The thing to replace the pattern with.
     */
    replaceRight(n, i) {
      const u = this.children[this.children.length - 1];
      return u[p2] ? u.replaceRight(n, i) : typeof u == "string" ? this.children[this.children.length - 1] = u.replace(
        n,
        i
      ) : this.children.push("".replace(n, i)), this;
    }
    /**
     * Set the source content for a source file. This will be added to the SourceMapGenerator
     * in the sourcesContent field.
     *
     * @param aSourceFile The filename of the source file
     * @param aSourceContent The content of the source file
     */
    setSourceContent(n, i) {
      this.sourceContents[f.toSetString(n)] = i;
    }
    /**
     * Walk over the tree of SourceNodes. The walking function is called for each
     * source file content and is passed the filename and source content.
     *
     * @param aFn The traversal function.
     */
    walkSourceContents(n) {
      for (let u = 0, d2 = this.children.length; u < d2; u++)
        this.children[u][p2] && this.children[u].walkSourceContents(n);
      const i = Object.keys(this.sourceContents);
      for (let u = 0, d2 = i.length; u < d2; u++)
        n(f.fromSetString(i[u]), this.sourceContents[i[u]]);
    }
    /**
     * Return the string representation of this source node. Walks over the tree
     * and concatenates all the various snippets together to one string.
     */
    toString() {
      let n = "";
      return this.walk(function(i) {
        n += i;
      }), n;
    }
    /**
     * Returns the string representation of this source node along with a source
     * map.
     */
    toStringWithSourceMap(n) {
      const i = {
        code: "",
        line: 1,
        column: 0
      }, u = new o(n);
      let d2 = false, C = null, r = null, e = null, s2 = null;
      return this.walk(function(c2, t) {
        i.code += c2, t.source !== null && t.line !== null && t.column !== null ? ((C !== t.source || r !== t.line || e !== t.column || s2 !== t.name) && u.addMapping({
          source: t.source,
          original: {
            line: t.line,
            column: t.column
          },
          generated: {
            line: i.line,
            column: i.column
          },
          name: t.name
        }), C = t.source, r = t.line, e = t.column, s2 = t.name, d2 = true) : d2 && (u.addMapping({
          generated: {
            line: i.line,
            column: i.column
          }
        }), C = null, d2 = false);
        for (let h = 0, _ = c2.length; h < _; h++)
          c2.charCodeAt(h) === b ? (i.line++, i.column = 0, h + 1 === _ ? (C = null, d2 = false) : d2 && u.addMapping({
            source: t.source,
            original: {
              line: t.line,
              column: t.column
            },
            generated: {
              line: i.line,
              column: i.column
            },
            name: t.name
          })) : i.column++;
      }), this.walkSourceContents(function(c2, t) {
        u.setSourceContent(c2, t);
      }), { code: i.code, map: u };
    }
  }
  return Q.SourceNode = y, Q;
}
var ue;
function Me() {
  return ue || (ue = 1, N.SourceMapGenerator = he().SourceMapGenerator, N.SourceMapConsumer = Ae().SourceMapConsumer, N.SourceNode = ve().SourceNode), N;
}
var K = Me();
var B = false;
function Oe() {
  if (!B)
    try {
      let o = null;
      try {
        const m = module$1.createRequire((typeof document === 'undefined' ? require('u' + 'rl').pathToFileURL(__filename).href : (_documentCurrentScript && _documentCurrentScript.tagName.toUpperCase() === 'SCRIPT' && _documentCurrentScript.src || new URL('service.js', document.baseURI).href))).resolve("source-map/package.json");
        o = Nodepath.join(Nodepath.dirname(m), "lib", "mappings.wasm");
      } catch {
        try {
          const f = [
            Nodepath.join(process.cwd(), "node_modules", "source-map", "lib", "mappings.wasm"),
            Nodepath.join(process.cwd(), "..", "node_modules", "source-map", "lib", "mappings.wasm"),
            Nodepath.join(process.cwd(), "..", "..", "node_modules", "source-map", "lib", "mappings.wasm")
          ];
          for (const m of f)
            if (Fs.existsSync(m)) {
              o = m;
              break;
            }
          o || (o = f[0]);
        } catch {
          o = Nodepath.join(process.cwd(), "node_modules", "source-map", "lib", "mappings.wasm");
        }
      }
      if (o && Fs.existsSync(o)) {
        const f = Fs.readFileSync(o), m = f.buffer.slice(
          f.byteOffset,
          f.byteOffset + f.byteLength
        );
        K.SourceMapConsumer.initialize({
          "lib/mappings.wasm": m
        }), B = true;
      } else if (o)
        K.SourceMapConsumer.initialize({
          "lib/mappings.wasm": o
        }), B = true;
      else
        throw new Error("Could not determine path to mappings.wasm");
    } catch (o) {
      console.warn("Failed to initialize SourceMapConsumer WASM:", o), B = false;
    }
}
async function Te(o) {
  if (!o.file.startsWith("about://React/Server/"))
    return o;
  try {
    let f = o.file.replace(/^about:\/\/React\/Server\//, "");
    f.startsWith("file:///") ? f = f.replace(/^file:\/\/\//, "/") : f.startsWith("file://") && (f = f.replace(/^file:\/\//, "/"));
    try {
      f = decodeURIComponent(f);
    } catch {
    }
    let m = f + ".map";
    if (!Fs.existsSync(m) && (m = f.replace(/\.js$/, ".map"), !Fs.existsSync(m) && (f.endsWith(".js") || (m = f + ".map"), !Fs.existsSync(m))))
      return o;
    const b = Fs.readFileSync(m, "utf-8"), p2 = JSON.parse(b);
    Oe();
    const y = await new Promise((n) => {
      K.SourceMapConsumer.with(p2, null, (i) => {
        n(i);
      });
    }), l = y.originalPositionFor({
      line: o.line,
      column: o.column
    });
    if (y.destroy(), l.source !== null && l.line !== null) {
      let n = l.source;
      if (n.startsWith("file:///") ? n = n.replace(/^file:\/\/\//, "/") : n.startsWith("file://") && (n = n.replace(/^file:\/\//, "/")), !n.startsWith("/"))
        if (p2.sourceRoot) {
          const i = Nodepath.dirname(m);
          p2.sourceRoot.startsWith("/") ? n = Nodepath.join(p2.sourceRoot, n) : n = Nodepath.join(i, p2.sourceRoot, n);
        } else {
          const i = Nodepath.dirname(m);
          n = Nodepath.join(i, n);
        }
      return n = n.replace(/\\/g, "/"), {
        file: n,
        line: l.line || o.line,
        column: l.column !== null ? l.column : o.column,
        componentName: o.componentName,
        sourceCode: o.sourceCode
      };
    }
    return o;
  } catch {
    return o;
  }
}

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Array.js
function make2(length3, x) {
  if (length3 <= 0) {
    return [];
  }
  let arr = new Array(length3);
  arr.fill(x);
  return arr;
}
function fromInitializer(length3, f) {
  if (length3 <= 0) {
    return [];
  }
  let arr = new Array(length3);
  for (let i = 0; i < length3; ++i) {
    arr[i] = f(i);
  }
  return arr;
}
function reduce(arr, init, f) {
  return arr.reduce(f, init);
}
function reduceWithIndex(arr, init, f) {
  return arr.reduce(f, init);
}
function filterMap(a, f) {
  let l = a.length;
  let r = new Array(l);
  let j2 = 0;
  for (let i = 0; i < l; ++i) {
    let v = a[i];
    let v$1 = f(v);
    if (v$1 !== void 0) {
      r[j2] = valFromOption(v$1);
      j2 = j2 + 1 | 0;
    }
  }
  r.length = j2;
  return r;
}

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Int.js
function fromString2(x, radix) {
  let maybeInt = parseInt(x);
  if (Number.isNaN(maybeInt) || maybeInt > 2147483647 || maybeInt < -2147483648) {
    return;
  } else {
    return maybeInt | 0;
  }
}
function execPromise(command, options) {
  return new Promise((resolve4, _reject) => {
    let cwd = options.cwd;
    let env = options.env;
    let maxBuffer = getOr(options.maxBuffer, 52428800);
    Nodechild_process__namespace.exec(command, {
      cwd,
      env,
      maxBuffer,
      encoding: "utf8"
    }, (err, stdout, stderr) => {
      if (err == null) {
        return resolve4({
          TAG: "Ok",
          _0: {
            stdout,
            stderr
          }
        });
      } else {
        return resolve4({
          TAG: "Error",
          _0: {
            code: fromNullable(err.code),
            stdout,
            stderr,
            message: err.message
          }
        });
      }
    });
  });
}
function spawnPromise(command, args, options) {
  let maxBuffer = getOr(options.maxBuffer, 52428800);
  return new Promise((resolve4, _reject) => {
    let cwd = options.cwd;
    let env = options.env;
    let proc = Nodechild_process__namespace.spawn(command, args, {
      cwd,
      env
    });
    let stdoutChunks = {
      contents: []
    };
    let stderrChunks = {
      contents: []
    };
    let stdoutLen = {
      contents: 0
    };
    let stderrLen = {
      contents: 0
    };
    let resolved = {
      contents: false
    };
    let guardedResolve = (value) => {
      if (resolved.contents) {
        return;
      } else {
        resolved.contents = true;
        return resolve4(value);
      }
    };
    proc.stdout.on("data", (chunk) => {
      if (resolved.contents) {
        return;
      } else {
        stdoutChunks.contents.push(chunk);
        stdoutLen.contents = stdoutLen.contents + chunk.byteLength | 0;
        if (stdoutLen.contents > maxBuffer) {
          proc.kill("SIGTERM");
          return guardedResolve({
            TAG: "Error",
            _0: {
              code: void 0,
              stdout: Nodebuffer__namespace.Buffer.concat(stdoutChunks.contents).toString("utf8"),
              stderr: Nodebuffer__namespace.Buffer.concat(stderrChunks.contents).toString("utf8"),
              message: "stdout maxBuffer exceeded"
            }
          });
        } else {
          return;
        }
      }
    });
    proc.stderr.on("data", (chunk) => {
      if (resolved.contents) {
        return;
      } else {
        stderrChunks.contents.push(chunk);
        stderrLen.contents = stderrLen.contents + chunk.byteLength | 0;
        if (stderrLen.contents > maxBuffer) {
          proc.kill("SIGTERM");
          return guardedResolve({
            TAG: "Error",
            _0: {
              code: void 0,
              stdout: Nodebuffer__namespace.Buffer.concat(stdoutChunks.contents).toString("utf8"),
              stderr: Nodebuffer__namespace.Buffer.concat(stderrChunks.contents).toString("utf8"),
              message: "stderr maxBuffer exceeded"
            }
          });
        } else {
          return;
        }
      }
    });
    proc.on("error", (err) => guardedResolve({
      TAG: "Error",
      _0: {
        code: void 0,
        stdout: Nodebuffer__namespace.Buffer.concat(stdoutChunks.contents).toString("utf8"),
        stderr: Nodebuffer__namespace.Buffer.concat(stderrChunks.contents).toString("utf8"),
        message: err.message
      }
    }));
    proc.on("close", (nullableCode) => {
      let code = nullableCode == null ? void 0 : some(nullableCode);
      if (!(nullableCode == null) && nullableCode === 0) {
        return guardedResolve({
          TAG: "Ok",
          _0: {
            stdout: Nodebuffer__namespace.Buffer.concat(stdoutChunks.contents).toString("utf8"),
            stderr: Nodebuffer__namespace.Buffer.concat(stderrChunks.contents).toString("utf8")
          }
        });
      }
      let codeStr = nullableCode == null ? "null" : nullableCode.toString();
      guardedResolve({
        TAG: "Error",
        _0: {
          code,
          stdout: Nodebuffer__namespace.Buffer.concat(stdoutChunks.contents).toString("utf8"),
          stderr: Nodebuffer__namespace.Buffer.concat(stderrChunks.contents).toString("utf8"),
          message: `Process exited with code ` + codeStr
        }
      });
    });
  });
}
async function execWithOptions(command, options) {
  let newrecord = { ...options };
  newrecord.maxBuffer = getOr(options.maxBuffer, 52428800);
  return await execPromise(command, newrecord);
}
async function spawnResult(command, args, cwd) {
  let options_maxBuffer = 52428800;
  let options = {
    cwd,
    maxBuffer: options_maxBuffer
  };
  return await spawnPromise(command, args, options);
}
function endsWithSep(path) {
  if (path.endsWith("/")) {
    return true;
  } else {
    return path.endsWith("\\");
  }
}
function resolve(sourceRoot, inputPath) {
  let normalizedRoot = Nodepath__namespace.normalize(sourceRoot);
  let rootWithSep = endsWithSep(normalizedRoot) ? normalizedRoot : normalizedRoot + Nodepath__namespace.sep;
  if (Nodepath__namespace.isAbsolute(inputPath)) {
    let normalizedPath = Nodepath__namespace.normalize(inputPath);
    if (normalizedPath === normalizedRoot || normalizedPath.startsWith(rootWithSep)) {
      return {
        TAG: "Ok",
        _0: {
          path: normalizedPath
        }
      };
    } else {
      return {
        TAG: "Error",
        _0: `Absolute path must be under source root: ` + inputPath
      };
    }
  }
  let fullPath = Nodepath__namespace.normalize(Nodepath__namespace.join(sourceRoot, inputPath));
  if (fullPath === normalizedRoot || fullPath.startsWith(rootWithSep)) {
    return {
      TAG: "Ok",
      _0: {
        path: fullPath
      }
    };
  } else {
    return {
      TAG: "Error",
      _0: `Path escapes source root: ` + inputPath
    };
  }
}
function toString(safePath) {
  return safePath.path;
}
function dirname2(safePath) {
  return Nodepath__namespace.dirname(safePath.path);
}

// ../frontman-core/src/FrontmanCore__PathContext.res.mjs
function endsWithSep2(path) {
  if (path.endsWith("/")) {
    return true;
  } else {
    return path.endsWith("\\");
  }
}
function toRelativePath(sourceRoot, absolutePath) {
  let normalizedRoot = endsWithSep2(sourceRoot) ? sourceRoot : sourceRoot + Nodepath__namespace.sep;
  if (absolutePath.startsWith(normalizedRoot)) {
    return absolutePath.slice(normalizedRoot.length, absolutePath.length);
  } else if (absolutePath.startsWith(sourceRoot)) {
    return absolutePath.slice(sourceRoot.length, absolutePath.length);
  } else {
    return absolutePath;
  }
}
function resolveSearchPath(sourceRoot, inputPath) {
  if (inputPath === void 0) {
    return sourceRoot;
  }
  if (!Nodepath__namespace.isAbsolute(inputPath)) {
    return Nodepath__namespace.join(sourceRoot, inputPath);
  }
  let normalizedPath = Nodepath__namespace.normalize(inputPath);
  let normalizedRoot = Nodepath__namespace.normalize(sourceRoot);
  if (normalizedPath.startsWith(normalizedRoot)) {
    return normalizedPath;
  } else {
    return sourceRoot;
  }
}
function detectPathConfusion(sourceRoot, requestedPath) {
  let normalizedPath = requestedPath.replaceAll("\\", "/").replace(/^\.\//, "").replace(/^\//, "");
  let firstSegment = getOr(normalizedPath.split("/")[0], "");
  let sourceSegments = sourceRoot.replaceAll("\\", "/").split("/");
  if (firstSegment !== "" && sourceSegments.includes(firstSegment)) {
    return `Path '` + requestedPath + `' not found. The sourceRoot is '` + sourceRoot + `' which already includes '` + firstSegment + `/'. Try using '.' or a path relative to sourceRoot instead.`;
  }
}
function dirname3(result) {
  return dirname2(result.safePath);
}
function resolve2(sourceRoot, inputPath) {
  let safePath = resolve(sourceRoot, inputPath);
  if (safePath.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: {
        message: safePath._0,
        hint: detectPathConfusion(sourceRoot, inputPath),
        sourceRoot,
        requestedPath: inputPath
      }
    };
  }
  let safePath$1 = safePath._0;
  let resolvedPath = toString(safePath$1);
  return {
    TAG: "Ok",
    _0: {
      safePath: safePath$1,
      sourceRoot,
      resolvedPath,
      relativePath: toRelativePath(sourceRoot, resolvedPath)
    }
  };
}
function formatError(err) {
  let base = err.message + ` (sourceRoot: ` + err.sourceRoot + `)`;
  let hint = err.hint;
  if (hint !== void 0) {
    return base + `

Hint: ` + hint;
  } else {
    return base;
  }
}

// ../frontman-protocol/src/FrontmanProtocol__Tool.res.mjs
var ToolNames = {
  writeFile: "write_file",
  readFile: "read_file",
  listFiles: "list_files",
  searchFiles: "search_files",
  grep: "grep",
  fileExists: "file_exists",
  loadAgentInstructions: "load_agent_instructions",
  lighthouse: "lighthouse"};

// ../frontman-core/src/tools/FrontmanCore__Tool__Grep.res.mjs
var name2 = ToolNames.grep;
var inputSchema = schema2((s2) => ({
  pattern: s2.m(string2),
  path: s2.m(option2(string2)),
  type: s2.m(option2(string2)),
  glob: s2.m(option2(string2)),
  case_insensitive: s2.m(option2(bool2)),
  literal: s2.m(option2(bool2)),
  max_results: s2.m(option2(int2))
}));
var matchLineSchema = schema2((s2) => ({
  lineNum: s2.m(int2),
  lineText: s2.m(string2)
}));
var fileMatchSchema = schema2((s2) => ({
  path: s2.m(string2),
  matches: s2.m(array2(matchLineSchema))
}));
var outputSchema = schema2((s2) => ({
  files: s2.m(array2(fileMatchSchema)),
  totalMatches: s2.m(int2),
  truncated: s2.m(bool2)
}));
function getRipgrepPath() {
  try {
    let vsCodeRipgrep = require_lib();
    return vsCodeRipgrep.rgPath;
  } catch (exn) {
    return;
  }
}
function buildRipgrepArgs(pattern2, searchPath, type_, glob, caseInsensitive, literal3, maxResults) {
  let args = [];
  args.push("-n");
  args.push("-H");
  if (caseInsensitive) {
    args.push("-i");
  }
  if (literal3) {
    args.push("-F");
  }
  args.push("-m");
  args.push(maxResults.toString());
  forEach(type_, (t) => {
    args.push("-t");
    args.push(t);
  });
  forEach(glob, (g) => {
    args.push("--glob");
    args.push(g);
  });
  args.push(pattern2);
  args.push(searchPath);
  return args;
}
function buildGitGrepArgs(pattern2, caseInsensitive, literal3, maxResults, glob, type_) {
  let args = [
    "grep",
    "-n",
    "-H"
  ];
  if (caseInsensitive) {
    args.push("-i");
  }
  if (literal3) {
    args.push("-F");
  }
  args.push("--max-count");
  args.push(maxResults.toString());
  args.push(pattern2);
  let hasPathspec = isSome(glob) || isSome(type_);
  if (hasPathspec) {
    args.push("--");
    if (glob !== void 0) {
      args.push(glob);
    }
    if (type_ !== void 0 && glob === void 0) {
      args.push(`*.` + type_);
    }
  }
  return args;
}
function parseGrepOutput(output, maxResults) {
  let lines = output.trim().split("\n").filter((line) => line !== "");
  let fileMap = {};
  let totalMatches = {
    contents: 0
  };
  lines.forEach((line) => {
    let colonIndex = line.indexOf(":");
    if (colonIndex <= 0) {
      return;
    }
    let rest = line.substring(colonIndex + 1 | 0);
    let secondColonIndex = rest.indexOf(":");
    if (secondColonIndex <= 0) {
      return;
    }
    let filePath = line.substring(0, colonIndex);
    let lineNumStr = rest.substring(0, secondColonIndex);
    let lineText = rest.substring(secondColonIndex + 1 | 0);
    let lineNum = fromString2(lineNumStr);
    if (lineNum === void 0) {
      return;
    }
    totalMatches.contents = totalMatches.contents + 1 | 0;
    let existing = fileMap[filePath];
    let matches2 = existing !== void 0 ? existing : [];
    matches2.push({
      lineNum,
      lineText
    });
    fileMap[filePath] = matches2;
  });
  let allFiles = Object.entries(fileMap).map((param) => ({
    path: param[0],
    matches: param[1]
  }));
  let totalFiles = allFiles.length;
  let files = allFiles.slice(0, maxResults);
  return {
    files,
    totalMatches: totalMatches.contents,
    truncated: totalFiles > maxResults
  };
}
async function executeRipgrep(rgPath, pattern2, searchPath, type_, glob, caseInsensitive, literal3, maxResults) {
  let args = buildRipgrepArgs(pattern2, searchPath, type_, glob, caseInsensitive, literal3, maxResults);
  let result = await spawnResult(rgPath, args, void 0);
  if (result.TAG === "Ok") {
    return {
      TAG: "Ok",
      _0: parseGrepOutput(result._0.stdout, maxResults)
    };
  }
  let match = result._0;
  let match$1 = match.code;
  if (match$1 === 1) {
    return {
      TAG: "Ok",
      _0: {
        files: [],
        totalMatches: 0,
        truncated: false
      }
    };
  }
  let stderr = match.stderr;
  let detail = stderr === "" ? match.message : stderr;
  return {
    TAG: "Error",
    _0: `Ripgrep failed: ` + detail
  };
}
async function executeGitGrep(pattern2, searchPath, caseInsensitive, literal3, maxResults, glob, type_) {
  let args = buildGitGrepArgs(pattern2, caseInsensitive, literal3, maxResults, glob, type_);
  let result = await spawnResult("git", args, searchPath);
  if (result.TAG === "Ok") {
    return {
      TAG: "Ok",
      _0: parseGrepOutput(result._0.stdout, maxResults)
    };
  }
  let match = result._0;
  let code = match.code;
  if (code === 1) {
    return {
      TAG: "Ok",
      _0: {
        files: [],
        totalMatches: 0,
        truncated: false
      }
    };
  }
  let stderr = match.stderr;
  let codeStr = getOr(map(code, (c2) => c2.toString()), "unknown");
  let detail = stderr === "" ? match.message : stderr;
  return {
    TAG: "Error",
    _0: `Git grep failed (exit ` + codeStr + `): ` + detail
  };
}
function buildPlainGrepArgs(pattern2, searchPath, caseInsensitive, literal3, maxResults, glob, type_) {
  let args = ["-rn"];
  if (caseInsensitive) {
    args.push("-i");
  }
  if (literal3) {
    args.push("-F");
  }
  args.push("-m");
  args.push(maxResults.toString());
  if (glob !== void 0) {
    args.push("--include");
    args.push(glob);
  } else if (type_ !== void 0) {
    args.push("--include");
    args.push(`*.` + type_);
  }
  args.push("--exclude-dir=node_modules");
  args.push("--exclude-dir=.git");
  args.push("--exclude-dir=dist");
  args.push("--exclude-dir=build");
  args.push("--exclude-dir=_build");
  args.push(pattern2);
  args.push(searchPath);
  return args;
}
async function executePlainGrep(pattern2, searchPath, caseInsensitive, literal3, maxResults, glob, type_) {
  let args = buildPlainGrepArgs(pattern2, searchPath, caseInsensitive, literal3, maxResults, glob, type_);
  let result = await spawnResult("grep", args, void 0);
  if (result.TAG === "Ok") {
    return {
      TAG: "Ok",
      _0: parseGrepOutput(result._0.stdout, maxResults)
    };
  }
  let match = result._0;
  let code = match.code;
  if (code === 1) {
    return {
      TAG: "Ok",
      _0: {
        files: [],
        totalMatches: 0,
        truncated: false
      }
    };
  }
  let stderr = match.stderr;
  let codeStr = getOr(map(code, (c2) => c2.toString()), "unknown");
  let detail = stderr === "" ? match.message : stderr;
  return {
    TAG: "Error",
    _0: `Grep failed (exit ` + codeStr + `): ` + detail
  };
}
async function execute(ctx2, input) {
  let searchPath = resolveSearchPath(ctx2.sourceRoot, input.path);
  let caseInsensitive = getOr(input.case_insensitive, false);
  let literal3 = getOr(input.literal, false);
  let maxResults = getOr(input.max_results, 20);
  let gitGrepWithFallback = async () => {
    let gitResult = await executeGitGrep(input.pattern, searchPath, caseInsensitive, literal3, maxResults, input.glob, input.type);
    if (gitResult.TAG === "Ok") {
      return gitResult;
    } else {
      return await executePlainGrep(input.pattern, searchPath, caseInsensitive, literal3, maxResults, input.glob, input.type);
    }
  };
  let rgPath = getRipgrepPath();
  if (rgPath === void 0) {
    return await gitGrepWithFallback();
  }
  let result = await executeRipgrep(rgPath, input.pattern, searchPath, input.type, input.glob, caseInsensitive, literal3, maxResults);
  if (result.TAG === "Ok") {
    return result;
  } else {
    return await gitGrepWithFallback();
  }
}
var description = `Fast content search tool that finds files containing specific text or patterns, returning matching lines sorted by file modification time.

WHEN TO USE THIS TOOL:
- Use when you need to find files containing specific text or patterns
- Great for searching code bases for function names, variable declarations, or error messages
- Useful for finding all files that use a particular API or pattern

PARAMETERS:
- pattern (required): The text or regex pattern to search for
- path (optional): Directory to search in (defaults to source root)
- type (optional): File type filter (e.g., "js", "ts", "py", "go")
- glob (optional): Glob pattern to filter files (e.g., "*.js", "*.{ts,tsx}")
- case_insensitive (optional): Case insensitive search (default: false)
- literal (optional): Treat pattern as literal text, not regex (default: false)
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Find "function" in JavaScript files: pattern="function", type="js"
- Find imports: pattern="import.*from", glob="*.ts"
- Case-insensitive search: pattern="error", case_insensitive=true
- Literal search: pattern="log.error()", literal=true

OUTPUT:
Returns matching lines grouped by file, with line numbers and content.
Results are sorted by file modification time (newest first).

LIMITATIONS:
- Results limited to max_results (default 20)
- Binary files are automatically skipped
- Hidden files (starting with '.') are skipped by default`;

// ../frontman-core/src/FrontmanCore__FileTracker.res.mjs
var readFiles = {
  contents: /* @__PURE__ */ new Set()
};
function recordRead(resolvedPath) {
  readFiles.contents.add(resolvedPath);
}
function assertReadBefore(resolvedPath) {
  if (readFiles.contents.has(resolvedPath)) {
    return {
      TAG: "Ok",
      _0: void 0
    };
  } else {
    return {
      TAG: "Error",
      _0: `File must be read before editing. Use read_file on "` + resolvedPath + `" first to see its current content.`
    };
  }
}

// ../frontman-core/src/tools/FrontmanCore__Tool__EditFile__Matcher.res.mjs
function levenshtein(a, b) {
  let match = a.length;
  let match$1 = b.length;
  if (match === 0) {
    return b.length;
  }
  if (match$1 === 0) {
    return a.length;
  }
  let matrix = fromInitializer(match + 1 | 0, (i) => fromInitializer(match$1 + 1 | 0, (j2) => {
    if (i !== 0) {
      if (j2 !== 0) {
        return 0;
      } else {
        return i;
      }
    } else {
      return j2;
    }
  }));
  for (let i = 1; i <= match; ++i) {
    for (let j2 = 1; j2 <= match$1; ++j2) {
      let cost = a.charAt(i - 1 | 0) === b.charAt(j2 - 1 | 0) ? 0 : 1;
      let del = getOrThrow(matrix[i - 1 | 0])[j2] + 1 | 0;
      let ins = getOrThrow(matrix[i])[j2 - 1 | 0] + 1 | 0;
      let sub = getOrThrow(matrix[i - 1 | 0])[j2 - 1 | 0] + cost | 0;
      getOrThrow(matrix[i])[j2] = min(del, min(ins, sub));
    }
  }
  return getOrThrow(matrix[match])[match$1];
}
function lineOffset(lines, lineIndex) {
  let offset = 0;
  for (let k2 = 0; k2 < lineIndex; ++k2) {
    offset = (offset + getOrThrow(lines[k2]).length | 0) + 1 | 0;
  }
  return offset;
}
function extractBlock(content, lines, startLine, endLine) {
  let startIdx = lineOffset(lines, startLine);
  let endIdx = lineOffset(lines, endLine) + getOrThrow(lines[endLine]).length | 0;
  return content.slice(startIdx, endIdx);
}
function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\$&");
}
function exactMatch(content, find) {
  if (content.includes(find)) {
    return [find];
  } else {
    return [];
  }
}
function lineTrimMatch(content, find) {
  let contentLines = content.split("\n");
  let searchLines = find.split("\n");
  let last = searchLines[searchLines.length - 1 | 0];
  let searchLines$1 = last === "" ? searchLines.slice(0, searchLines.length - 1 | 0) : searchLines;
  let searchLen = searchLines$1.length;
  let results = [];
  for (let i = 0, i_finish = contentLines.length - searchLen | 0; i <= i_finish; ++i) {
    let matches2 = true;
    let j2 = 0;
    while (j2 < searchLen && matches2) {
      let origTrimmed = getOrThrow(contentLines[i + j2 | 0]).trim();
      let searchTrimmed = getOrThrow(searchLines$1[j2]).trim();
      if (origTrimmed === searchTrimmed) {
        j2 = j2 + 1 | 0;
      } else {
        matches2 = false;
      }
    }
    if (matches2) {
      results.push(extractBlock(content, contentLines, i, (i + searchLen | 0) - 1 | 0));
    }
  }
  return results;
}
function anchoredBlockMatch(content, find) {
  let contentLines = content.split("\n");
  let searchLines = find.split("\n");
  let last = searchLines[searchLines.length - 1 | 0];
  let searchLines$1 = last === "" ? searchLines.slice(0, searchLines.length - 1 | 0) : searchLines;
  if (searchLines$1.length < 3) {
    return [];
  }
  let firstLineSearch = getOrThrow(searchLines$1[0]).trim();
  let lastLineSearch = getOrThrow(searchLines$1[searchLines$1.length - 1 | 0]).trim();
  let searchBlockSize = searchLines$1.length;
  let candidates = [];
  for (let i = 0, i_finish = contentLines.length; i < i_finish; ++i) {
    if (getOrThrow(contentLines[i]).trim() === firstLineSearch) {
      let j2 = i + 2 | 0;
      while (j2 < contentLines.length) {
        if (getOrThrow(contentLines[j2]).trim() === lastLineSearch) {
          candidates.push({
            startLine: i,
            endLine: j2
          });
          j2 = j2 + 1 | 0;
        } else {
          j2 = j2 + 1 | 0;
        }
      }
    }
  }
  let match = candidates.length;
  if (match === 0) {
    return [];
  }
  if (match !== 1) {
    let bestMatch = {
      contents: void 0
    };
    let maxSim = {
      contents: -1
    };
    candidates.forEach((cand) => {
      let startLine2 = cand.startLine;
      let actualBlockSize2 = (cand.endLine - startLine2 | 0) + 1 | 0;
      let linesToCheck2 = min(searchBlockSize - 2 | 0, actualBlockSize2 - 2 | 0);
      let similarity2;
      if (linesToCheck2 > 0) {
        let sim = 0;
        for (let j2 = 1, j_finish = min(searchBlockSize - 2 | 0, actualBlockSize2 - 2 | 0); j2 <= j_finish; ++j2) {
          let origLine = getOrThrow(contentLines[startLine2 + j2 | 0]).trim();
          let searchLine = getOrThrow(searchLines$1[j2]).trim();
          let maxLen = max(origLine.length, searchLine.length);
          if (maxLen > 0) {
            let distance = levenshtein(origLine, searchLine);
            sim = sim + (1 - distance / maxLen);
          }
        }
        similarity2 = sim / linesToCheck2;
      } else {
        similarity2 = 1;
      }
      if (similarity2 > maxSim.contents) {
        maxSim.contents = similarity2;
        bestMatch.contents = cand;
        return;
      }
    });
    let match$1 = maxSim.contents >= 0.3;
    let match$2 = bestMatch.contents;
    if (match$1) {
      if (match$2 !== void 0) {
        return [extractBlock(content, contentLines, match$2.startLine, match$2.endLine)];
      } else {
        return [];
      }
    } else {
      return [];
    }
  }
  let match$3 = getOrThrow(candidates[0]);
  let endLine = match$3.endLine;
  let startLine = match$3.startLine;
  let actualBlockSize = (endLine - startLine | 0) + 1 | 0;
  let linesToCheck = min(searchBlockSize - 2 | 0, actualBlockSize - 2 | 0);
  let similarity;
  if (linesToCheck > 0) {
    let sim = 0;
    let j$1 = 1;
    while (j$1 < (searchBlockSize - 1 | 0) && j$1 < (actualBlockSize - 1 | 0)) {
      let origLine = getOrThrow(contentLines[startLine + j$1 | 0]).trim();
      let searchLine = getOrThrow(searchLines$1[j$1]).trim();
      let maxLen = max(origLine.length, searchLine.length);
      if (maxLen > 0) {
        let distance = levenshtein(origLine, searchLine);
        sim = sim + (1 - distance / maxLen) / linesToCheck;
      }
      j$1 = sim >= 0 ? searchBlockSize : j$1 + 1 | 0;
    }
    similarity = sim;
  } else {
    similarity = 1;
  }
  if (similarity >= 0) {
    return [extractBlock(content, contentLines, startLine, endLine)];
  } else {
    return [];
  }
}
function normalizedWhitespaceMatch(content, find) {
  let normalize3 = (text) => text.replace(/\s+/g, " ").trim();
  let normalizedFind = normalize3(find);
  let contentLines = content.split("\n");
  let results = [];
  contentLines.forEach((line) => {
    if (normalize3(line) === normalizedFind) {
      results.push(line);
      return;
    }
    let normalizedLine = normalize3(line);
    if (!normalizedLine.includes(normalizedFind)) {
      return;
    }
    let words = filterMap(find.trim().split(/\s+/), (x) => x);
    if (words.length === 0) {
      return;
    }
    let pattern2 = words.map(escapeRegex).join("\\s+");
    try {
      let regex = new RegExp(pattern2);
      let result = line.match(regex);
      if (result == null) {
        return;
      }
      let m = result[0];
      if (m.length > 0) {
        results.push(m);
        return;
      } else {
        return;
      }
    } catch (exn) {
      return;
    }
  });
  let findLines = find.split("\n");
  if (findLines.length > 1) {
    for (let i = 0, i_finish = contentLines.length - findLines.length | 0; i <= i_finish; ++i) {
      let block = contentLines.slice(i, i + findLines.length | 0).join("\n");
      if (normalize3(block) === normalizedFind) {
        results.push(block);
      }
    }
  }
  return results;
}
function flexibleIndentMatch(content, find) {
  let removeIndent = (text) => {
    let lines = text.split("\n");
    let nonEmptyLines = lines.filter((line) => line.trim().length > 0);
    let match = nonEmptyLines.length;
    if (match === 0) {
      return text;
    }
    let minIndent = reduce(nonEmptyLines, 999999, (acc, line) => {
      let m = line.match(/^(\s*)/);
      let indent = !(m == null) ? m[0].length : 0;
      return min(acc, indent);
    });
    return lines.map((line) => {
      let match2 = line.trim().length;
      if (match2 !== 0) {
        return line.slice(minIndent, line.length);
      } else {
        return line;
      }
    }).join("\n");
  };
  let normalizedFind = removeIndent(find);
  let contentLines = content.split("\n");
  let findLines = find.split("\n");
  let results = [];
  for (let i = 0, i_finish = contentLines.length - findLines.length | 0; i <= i_finish; ++i) {
    let block = contentLines.slice(i, i + findLines.length | 0).join("\n");
    if (removeIndent(block) === normalizedFind) {
      results.push(block);
    }
  }
  return results;
}
function escapeNormalizedMatch(content, find) {
  let unescape = (function(str) {
    return str.replace(/\\([ntr'"\\/$])/g, function(_m, c2) {
      if (c2 === "n") return String.fromCharCode(10);
      if (c2 === "t") return String.fromCharCode(9);
      if (c2 === "r") return String.fromCharCode(13);
      return c2;
    });
  });
  let unescapedFind = unescape(find);
  let results = [];
  if (content.includes(unescapedFind)) {
    results.push(unescapedFind);
  }
  let contentLines = content.split("\n");
  let findLines = unescapedFind.split("\n");
  for (let i = 0, i_finish = contentLines.length - findLines.length | 0; i <= i_finish; ++i) {
    let block = contentLines.slice(i, i + findLines.length | 0).join("\n");
    let unescapedBlock = unescape(block);
    if (unescapedBlock === unescapedFind && !results.includes(block)) {
      results.push(block);
    }
  }
  return results;
}
function trimmedBoundaryMatch(content, find) {
  let trimmedFind = find.trim();
  if (trimmedFind === find) {
    return [];
  }
  let results = [];
  if (content.includes(trimmedFind)) {
    results.push(trimmedFind);
  }
  let contentLines = content.split("\n");
  let findLines = find.split("\n");
  for (let i = 0, i_finish = contentLines.length - findLines.length | 0; i <= i_finish; ++i) {
    let block = contentLines.slice(i, i + findLines.length | 0).join("\n");
    if (block.trim() === trimmedFind && !results.includes(block)) {
      results.push(block);
    }
  }
  return results;
}
function contextAnchorMatch(content, find) {
  let findLines = find.split("\n");
  let last = findLines[findLines.length - 1 | 0];
  let findLines$1 = last === "" ? findLines.slice(0, findLines.length - 1 | 0) : findLines;
  if (findLines$1.length < 3) {
    return [];
  }
  let contentLines = content.split("\n");
  let firstLine = getOrThrow(findLines$1[0]).trim();
  let lastLine = getOrThrow(findLines$1[findLines$1.length - 1 | 0]).trim();
  let results = [];
  for (let i = 0, i_finish = contentLines.length; i < i_finish; ++i) {
    if (getOrThrow(contentLines[i]).trim() === firstLine) {
      let j2 = i + 2 | 0;
      while (j2 < contentLines.length) {
        if (getOrThrow(contentLines[j2]).trim() === lastLine) {
          let blockLines = contentLines.slice(i, j2 + 1 | 0);
          if (blockLines.length === findLines$1.length) {
            let matchingLines = 0;
            let totalNonEmpty = 0;
            for (let k2 = 1, k_finish = blockLines.length - 2 | 0; k2 <= k_finish; ++k2) {
              let blockLine = getOrThrow(blockLines[k2]).trim();
              let findLine = getOrThrow(findLines$1[k2]).trim();
              let match = blockLine.length > 0;
              let match$1 = findLine.length > 0;
              let exit = 0;
              if (match || match$1) {
                exit = 1;
              }
              if (exit === 1) {
                totalNonEmpty = totalNonEmpty + 1 | 0;
                if (blockLine === findLine) {
                  matchingLines = matchingLines + 1 | 0;
                }
              }
            }
            let total = totalNonEmpty;
            let passes = total !== 0 ? matchingLines / total >= 0.5 : true;
            if (passes) {
              results.push(extractBlock(content, contentLines, i, j2));
            }
          }
          j2 = j2 + 1 | 0;
        } else {
          j2 = j2 + 1 | 0;
        }
      }
    }
  }
  return results;
}
function multiOccurrenceMatch(content, find) {
  let results = [];
  let startIndex = {
    contents: 0
  };
  let continue_ = true;
  while (continue_) {
    let searchContent = content.slice(startIndex.contents, content.length);
    let idx = map(indexOfOpt(searchContent, find), (i) => i + startIndex.contents | 0);
    if (idx !== void 0) {
      results.push(find);
      startIndex.contents = idx + find.length | 0;
    } else {
      continue_ = false;
    }
  }
  return results;
}
var strategies = [
  exactMatch,
  lineTrimMatch,
  anchoredBlockMatch,
  normalizedWhitespaceMatch,
  flexibleIndentMatch,
  escapeNormalizedMatch,
  trimmedBoundaryMatch,
  contextAnchorMatch,
  multiOccurrenceMatch
];
function applyEdit(content, oldText, newText, replaceAllOpt) {
  let replaceAll = replaceAllOpt !== void 0 ? replaceAllOpt : false;
  let notFound = {
    contents: true
  };
  let result = {
    contents: void 0
  };
  let strategyIdx = 0;
  while (isNone(result.contents) && strategyIdx < strategies.length) {
    let strategy = getOrThrow(strategies[strategyIdx]);
    let candidates = strategy(content, oldText);
    let match = !replaceAll && candidates.length > 1;
    if (match) {
      notFound.contents = false;
    } else if (replaceAll) {
      candidates.forEach((candidate) => {
        let match2 = result.contents;
        if (match2 !== void 0) {
          return;
        }
        let idx = content.indexOf(candidate);
        if (idx >= 0) {
          notFound.contents = false;
          result.contents = {
            TAG: "Applied",
            _0: content.split(candidate).join(newText)
          };
          return;
        }
      });
    } else {
      let candidate = candidates[0];
      if (candidate !== void 0) {
        let idx = content.indexOf(candidate);
        if (idx >= 0) {
          notFound.contents = false;
          let lastIdx = content.lastIndexOf(candidate);
          if (idx === lastIdx) {
            let before = content.slice(0, idx);
            let after = content.slice(idx + candidate.length | 0, content.length);
            result.contents = {
              TAG: "Applied",
              _0: before + newText + after
            };
          }
        }
      }
    }
    strategyIdx = strategyIdx + 1 | 0;
  }
  let r = result.contents;
  if (r !== void 0) {
    return r;
  } else if (notFound.contents) {
    return "NotFound";
  } else {
    return "Ambiguous";
  }
}

// ../frontman-core/src/tools/FrontmanCore__Tool__EditFile.res.mjs
var inputSchema2 = schema2((s2) => ({
  path: s2.m(string2),
  oldText: s2.m(string2),
  newText: s2.m(string2),
  replaceAll: s2.m(option2(bool2))
}));
var pathContextSchema = schema2((s2) => ({
  sourceRoot: s2.m(string2),
  resolvedPath: s2.m(string2),
  relativePath: s2.m(string2)
}));
var outputSchema2 = schema2((s2) => ({
  message: s2.m(string2),
  _context: s2.m(option2(pathContextSchema))
}));
async function execute2(ctx2, input) {
  let replaceAll = getOr(input.replaceAll, false);
  if (input.oldText === input.newText) {
    return {
      TAG: "Error",
      _0: "oldText and newText must be different"
    };
  }
  let err = resolve2(ctx2.sourceRoot, input.path);
  if (err.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: formatError(err._0)
    };
  }
  let result = err._0;
  let pathCtx_sourceRoot = result.sourceRoot;
  let pathCtx_resolvedPath = result.resolvedPath;
  let pathCtx_relativePath = result.relativePath;
  let pathCtx = {
    sourceRoot: pathCtx_sourceRoot,
    resolvedPath: pathCtx_resolvedPath,
    relativePath: pathCtx_relativePath
  };
  if (input.oldText === "") {
    try {
      let dirPath = dirname3(result);
      await Fs__namespace.promises.mkdir(dirPath, {
        recursive: true
      });
      await Fs__namespace.promises.writeFile(result.resolvedPath, input.newText, "utf8");
      return {
        TAG: "Ok",
        _0: {
          message: "File created successfully.",
          _context: pathCtx
        }
      };
    } catch (raw_exn) {
      let exn = internalToException(raw_exn);
      let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
      return {
        TAG: "Error",
        _0: `Failed to create file ` + input.path + `: ` + msg
      };
    }
  } else {
    let msg$1 = assertReadBefore(result.resolvedPath);
    if (msg$1.TAG !== "Ok") {
      return {
        TAG: "Error",
        _0: msg$1._0
      };
    }
    try {
      let content = await Fs__namespace.promises.readFile(result.resolvedPath, "utf8");
      let newContent = applyEdit(content, input.oldText, input.newText, replaceAll);
      if (typeof newContent !== "object") {
        if (newContent === "NotFound") {
          return {
            TAG: "Error",
            _0: `oldText not found in file ` + input.path + `. Make sure the text matches exactly, or read the file again to see its current content.`
          };
        } else {
          return {
            TAG: "Error",
            _0: `Found multiple matches for oldText in ` + input.path + `. Provide more surrounding context to identify the correct match, or use replaceAll to replace all occurrences.`
          };
        }
      }
      await Fs__namespace.promises.writeFile(result.resolvedPath, newContent._0, "utf8");
      return {
        TAG: "Ok",
        _0: {
          message: "Edit applied successfully.",
          _context: pathCtx
        }
      };
    } catch (raw_exn$1) {
      let exn$1 = internalToException(raw_exn$1);
      let msg$2 = getOr(flatMap(fromException(exn$1), message2), "Unknown error");
      return {
        TAG: "Error",
        _0: `Failed to edit file ` + input.path + `: ` + msg$2
      };
    }
  }
}
var name3 = "edit_file";
var description2 = `Edits a file by replacing text using fuzzy matching.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- oldText (required): The text to find and replace. An empty oldText creates a new file with newText as content.
- newText (required): The replacement text (must differ from oldText)
- replaceAll (optional): If true, replaces all occurrences. Default: false.

The tool uses multiple matching strategies (exact, line-trimmed, whitespace-normalized,
indentation-flexible, etc.) to handle common formatting differences.

IMPORTANT: You must read_file before editing. The tool will reject edits on unread files.`;
var name4 = ToolNames.readFile;
var inputSchema3 = schema2((s2) => ({
  path: s2.m(string2),
  offset: s2.m(option2(int2)),
  limit: s2.m(option2(int2))
}));
var pathContextSchema2 = schema2((s2) => ({
  sourceRoot: s2.m(string2),
  resolvedPath: s2.m(string2),
  relativePath: s2.m(string2)
}));
var outputSchema3 = schema2((s2) => ({
  content: s2.m(string2),
  totalLines: s2.m(int2),
  hasMore: s2.m(bool2),
  _context: s2.m(option2(pathContextSchema2))
}));
async function execute3(ctx2, input) {
  let offset = getOr(input.offset, 0);
  let limit = getOr(input.limit, 500);
  let err = resolve2(ctx2.sourceRoot, input.path);
  if (err.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: formatError(err._0)
    };
  }
  let result = err._0;
  try {
    let content = await Fs__namespace.promises.readFile(result.resolvedPath, "utf8");
    let lines = content.split("\n");
    let totalLines = lines.length;
    let selectedLines = lines.slice(offset, offset + limit | 0);
    let selectedContent = selectedLines.join("\n");
    let hasMore = (offset + limit | 0) < totalLines;
    recordRead(result.resolvedPath);
    return {
      TAG: "Ok",
      _0: {
        content: selectedContent,
        totalLines,
        hasMore,
        _context: {
          sourceRoot: result.sourceRoot,
          resolvedPath: result.resolvedPath,
          relativePath: result.relativePath
        }
      }
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to read file ` + input.path + `: ` + msg
    };
  }
}
var description3 = `Reads a file from the filesystem.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- offset (optional): Line number to start from (0-indexed, default: 0). Pass null or 0 to start from beginning.
- limit (optional): Maximum lines to read (default: 500). Pass null or 500 for default.

Returns file content with metadata about total lines and whether more content exists.
The _context field provides path resolution details for debugging.`;

// ../../node_modules/@rescript/runtime/lib/es6/Stdlib_Result.js
function map3(opt, f) {
  if (opt.TAG === "Ok") {
    return {
      TAG: "Ok",
      _0: f(opt._0)
    };
  } else {
    return opt;
  }
}

// ../frontman-core/src/tools/FrontmanCore__Tool__ListFiles.res.mjs
var name5 = ToolNames.listFiles;
var inputSchema4 = schema2((s2) => ({
  path: s2.m(option2(string2))
}));
var fileEntrySchema = schema2((s2) => ({
  name: s2.m(string2),
  path: s2.m(string2),
  isFile: s2.m(bool2),
  isDirectory: s2.m(bool2)
}));
var outputSchema4 = array2(fileEntrySchema);
async function getIgnoredEntries(cwd, entries) {
  if (entries.length === 0) {
    return {
      TAG: "Ok",
      _0: []
    };
  }
  try {
    let entriesArg = entries.join("\n");
    let command = `printf "%s" "` + entriesArg + `" | git check-ignore --stdin`;
    let result = await execWithOptions(command, {
      cwd
    });
    if (result.TAG === "Ok") {
      return {
        TAG: "Ok",
        _0: result._0.stdout.trim().split("\n").filter((s2) => s2 !== "")
      };
    }
    let match = result._0;
    let match$1 = match.code;
    let exit = 0;
    if (match$1 !== void 0) {
      if (match$1 === 1) {
        return {
          TAG: "Ok",
          _0: []
        };
      }
      if (match$1 === 128) {
        return {
          TAG: "Error",
          _0: `Not a git repository: ` + match.stderr
        };
      }
      exit = 1;
    } else {
      exit = 1;
    }
    if (exit === 1) {
      return {
        TAG: "Error",
        _0: `git check-ignore failed: ` + match.stderr
      };
    }
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `git check-ignore error: ` + msg
    };
  }
}
async function execute4(ctx2, input) {
  let path = getOr(input.path, ".");
  let err = resolve2(ctx2.sourceRoot, path);
  if (err.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: formatError(err._0)
    };
  }
  try {
    let fullPath = err._0.resolvedPath;
    let entries = await Fs__namespace.promises.readdir(fullPath);
    let filteredEntriesResult = map3(await getIgnoredEntries(fullPath, entries), (ignored) => entries.filter((name13) => !ignored.includes(name13)));
    if (filteredEntriesResult.TAG !== "Ok") {
      return {
        TAG: "Error",
        _0: filteredEntriesResult._0
      };
    }
    let entriesWithStats = await Promise.all(filteredEntriesResult._0.map(async (name13) => {
      let entryPath = Nodepath__namespace.join(fullPath, name13);
      let stats = await Fs__namespace.promises.stat(entryPath);
      return {
        name: name13,
        path: Nodepath__namespace.join(path, name13),
        isFile: stats.isFile(),
        isDirectory: stats.isDirectory()
      };
    }));
    return {
      TAG: "Ok",
      _0: entriesWithStats
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to list files in ` + path + `: ` + msg
    };
  }
}
var description4 = `Lists files and directories in a given path.

Parameters:
- path (optional): Path to directory - either relative to source root or absolute (must be under source root). Defaults to "." (root directory).

Returns array of entries with name, path, and type information.`;
var name6 = ToolNames.writeFile;
var inputSchema5 = schema2((s2) => ({
  path: s2.m(string2),
  content: s2.m(option2(string2)),
  image_ref: s2.m(option2(string2)),
  encoding: s2.m(option2(literal2("base64")))
}));
var pathContextSchema3 = schema2((s2) => ({
  sourceRoot: s2.m(string2),
  resolvedPath: s2.m(string2),
  relativePath: s2.m(string2)
}));
var outputSchema5 = schema2((s2) => ({
  _context: s2.m(option2(pathContextSchema3))
}));
function writeContent(resolvedPath, content, encoding) {
  if (encoding === void 0) {
    return Fs__namespace.promises.writeFile(resolvedPath, content, "utf8");
  }
  let buffer = Nodebuffer__namespace.Buffer.from(content, "base64");
  return Fs__namespace.promises.writeFile(resolvedPath, buffer);
}
async function execute5(ctx2, input) {
  let match = input.content;
  let match$1 = input.image_ref;
  if (match === void 0) {
    if (match$1 !== void 0) {
      return {
        TAG: "Error",
        _0: "image_ref must be resolved to content before execution"
      };
    } else {
      return {
        TAG: "Error",
        _0: "Either content or image_ref must be provided"
      };
    }
  }
  if (match$1 !== void 0) {
    return {
      TAG: "Error",
      _0: "Provide either content or image_ref, not both"
    };
  }
  let err = resolve2(ctx2.sourceRoot, input.path);
  if (err.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: formatError(err._0)
    };
  }
  let result = err._0;
  try {
    await Fs__namespace.promises.mkdir(dirname3(result), {
      recursive: true
    });
    await writeContent(result.resolvedPath, match, input.encoding);
    return {
      TAG: "Ok",
      _0: {
        _context: {
          sourceRoot: result.sourceRoot,
          resolvedPath: result.resolvedPath,
          relativePath: result.relativePath
        }
      }
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to write file ` + input.path + `: ` + msg
    };
  }
}
var description5 = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content: Text content to write (mutually exclusive with image_ref)
- image_ref: URI of a user-attached image to save (e.g., "attachment://att_abc123/photo.png"). Use this to save images the user has pasted into the chat. Mutually exclusive with content.
- encoding: Set to "base64" when writing binary data (used internally when image_ref is resolved)

Provide either content OR image_ref, not both.
Creates parent directories if they don't exist. Overwrites existing files.
The _context field provides path resolution details for debugging.`;
var name7 = ToolNames.fileExists;
var inputSchema6 = schema2((s2) => ({
  path: s2.m(string2)
}));
async function execute6(ctx2, input) {
  let msg = resolve(ctx2.sourceRoot, input.path);
  if (msg.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: msg._0
    };
  }
  try {
    await Fs__namespace.promises.access(toString(msg._0));
    return {
      TAG: "Ok",
      _0: true
    };
  } catch (exn) {
    return {
      TAG: "Ok",
      _0: false
    };
  }
}
var description6 = `Checks if a file or directory exists.

Parameters:
- path (required): Path to check - either relative to source root or absolute (must be under source root)

Returns true if the path exists, false otherwise.`;
var outputSchema6 = bool2;

// ../bindings/src/Lighthouse.res.mjs
var run = ((url2, flags2) => import('module').then(({ createRequire }) => {
  const req = createRequire((typeof document === 'undefined' ? require('u' + 'rl').pathToFileURL(__filename).href : (_documentCurrentScript && _documentCurrentScript.tagName.toUpperCase() === 'SCRIPT' && _documentCurrentScript.src || new URL('service.js', document.baseURI).href)));
  try {
    const mod = req("lighthouse");
    const lighthouse = mod.default ?? mod;
    return lighthouse(url2, flags2);
  } catch (e) {
    if (e.code === "MODULE_NOT_FOUND") {
      throw new Error("lighthouse is not installed. Run: npm install lighthouse");
    }
    throw e;
  }
}));

// ../bindings/src/ChromeLauncher.res.mjs
var launch = ((options) => import('module').then(({ createRequire }) => {
  const req = createRequire((typeof document === 'undefined' ? require('u' + 'rl').pathToFileURL(__filename).href : (_documentCurrentScript && _documentCurrentScript.tagName.toUpperCase() === 'SCRIPT' && _documentCurrentScript.src || new URL('service.js', document.baseURI).href)));
  try {
    const mod = req("chrome-launcher");
    return mod.launch(options);
  } catch (e) {
    if (e.code === "MODULE_NOT_FOUND") {
      throw new Error("chrome-launcher is not installed. Run: npm install chrome-launcher");
    }
    throw e;
  }
}));
async function killSafely(chrome) {
  try {
    return await chrome.kill();
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    console.error(`[chrome-launcher] Failed to kill Chrome (pid ` + chrome.pid.toString() + `): ` + msg);
    return;
  }
}

// ../frontman-core/src/tools/FrontmanCore__Tool__Lighthouse.res.mjs
var name8 = ToolNames.lighthouse;
var inputSchema7 = schema2((s2) => ({
  url: s2.m(string2),
  preset: s2.m(option2(string2))
}));
var auditIssueSchema = schema2((s2) => ({
  id: s2.m(string2),
  title: s2.m(string2),
  description: s2.m(string2),
  score: s2.m(float2),
  displayValue: s2.m(option2(string2))
}));
var categoryResultSchema = schema2((s2) => ({
  id: s2.m(string2),
  title: s2.m(string2),
  score: s2.m(int2),
  topIssues: s2.m(array2(auditIssueSchema))
}));
var outputSchema7 = schema2((s2) => ({
  url: s2.m(string2),
  fetchTime: s2.m(string2),
  categories: s2.m(array2(categoryResultSchema)),
  overallScore: s2.m(int2),
  warnings: s2.m(array2(string2))
}));
var categoryIds = [
  "performance",
  "accessibility",
  "best-practices",
  "seo"
];
function getTopIssues(category, audits, maxIssues) {
  return filterMap(category.auditRefs, (ref) => audits[ref.id]).filter((audit) => {
    let score = audit.score;
    if (!(score == null) && (audit.scoreDisplayMode === "binary" || audit.scoreDisplayMode === "numeric" || audit.scoreDisplayMode === "metricSavings")) {
      return score < 1;
    } else {
      return false;
    }
  }).toSorted((a, b) => {
    let scoreA = getOr(fromNullable(a.score), 0);
    let scoreB = getOr(fromNullable(b.score), 0);
    return scoreA - scoreB;
  }).slice(0, maxIssues).map((audit) => ({
    id: audit.id,
    title: audit.title,
    description: audit.description,
    score: getOr(fromNullable(audit.score), 0),
    displayValue: audit.displayValue
  }));
}
function processLhr(lhr) {
  let categories = filterMap(categoryIds, (id) => lhr.categories[id]).map((category) => {
    let s2 = category.score;
    let score = !(s2 == null) ? Math.round(s2 * 100) | 0 : 0;
    let topIssues = getTopIssues(category, lhr.audits, 3);
    return {
      id: category.id,
      title: category.title,
      score,
      topIssues
    };
  });
  let totalScore = reduce(categories, 0, (acc, cat) => acc + cat.score | 0);
  let len = categories.length;
  let overallScore = len !== 0 ? div(totalScore, len) : 0;
  return {
    url: lhr.finalDisplayedUrl,
    fetchTime: lhr.fetchTime,
    categories,
    overallScore,
    warnings: lhr.runWarnings
  };
}
async function runLighthouse(chrome, url2, preset) {
  let port2 = chrome.port;
  let flags_port = port2;
  let flags_output = "json";
  let flags_logLevel = "error";
  let flags_onlyCategories = categoryIds;
  let flags_formFactor = preset;
  let flags_screenEmulation = {
    disabled: preset === "desktop"
  };
  let flags_throttlingMethod = "simulate";
  let flags2 = {
    port: flags_port,
    output: flags_output,
    logLevel: flags_logLevel,
    onlyCategories: flags_onlyCategories,
    formFactor: flags_formFactor,
    screenEmulation: flags_screenEmulation,
    throttlingMethod: flags_throttlingMethod
  };
  try {
    let runnerResult = await run(url2, flags2);
    await killSafely(chrome);
    if (runnerResult == null) {
      return {
        TAG: "Error",
        _0: "Lighthouse returned no results. The URL may be unreachable."
      };
    } else {
      return {
        TAG: "Ok",
        _0: processLhr(runnerResult.lhr)
      };
    }
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    await killSafely(chrome);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Lighthouse audit failed: ` + msg
    };
  }
}
async function execute7(_ctx, input) {
  let preset = getOr(input.preset, "desktop");
  switch (preset) {
    case "desktop":
    case "mobile":
      break;
    default:
      return {
        TAG: "Error",
        _0: `Invalid preset "` + preset + `". Must be "desktop" or "mobile".`
      };
  }
  try {
    let chrome = await launch({
      chromeFlags: [
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage"
      ]
    });
    return await runLighthouse(chrome, input.url, preset);
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to launch Chrome: ` + msg + `. Make sure Chrome is installed on the system.`
    };
  }
}
var description7 = `Runs a Lighthouse audit on a URL to analyze performance, accessibility, best practices, and SEO.

WHEN TO USE THIS TOOL:
- After making changes that might affect page load performance
- When implementing new UI components to check accessibility
- Before deploying to verify web best practices
- To diagnose why a page feels slow

PARAMETERS:
- url (required): The full URL to audit (e.g., "http://localhost:3000/")
- preset (optional): "desktop" (default) or "mobile" for mobile emulation
  IMPORTANT: Check the current_page context for device_emulation - if a mobile device is being emulated (e.g., iPhone, Pixel), use preset: "mobile" to match the user's testing context.

OUTPUT:
Returns scores (0-100) for each category plus the top 3 issues to fix in each category.
Higher scores are better. Issues include actionable descriptions.

LIMITATIONS:
- Requires Chrome to be installed on the system
- Takes 15-30 seconds to complete
- Results can vary between runs (\xB15 points is normal)
- URL must be accessible from the machine running the audit`;
var name9 = ToolNames.searchFiles;
var inputSchema8 = schema2((s2) => ({
  pattern: s2.m(string2),
  path: s2.m(option2(string2)),
  max_results: s2.m(option2(int2))
}));
var outputSchema8 = schema2((s2) => ({
  files: s2.m(array2(string2)),
  totalResults: s2.m(int2),
  truncated: s2.m(bool2)
}));
function getRipgrepPath2() {
  try {
    let vsCodeRipgrep = require_lib();
    return vsCodeRipgrep.rgPath;
  } catch (exn) {
    return;
  }
}
function buildRipgrepArgs2(searchPath) {
  let args = [];
  args.push("--files");
  args.push("--hidden");
  args.push("--no-ignore");
  args.push(searchPath);
  return args;
}
function matchesPattern(fileName2, patternLower) {
  let fileNameLower = fileName2.toLowerCase();
  if (patternLower === "") {
    return true;
  }
  if (!patternLower.includes("*")) {
    return fileNameLower.includes(patternLower);
  }
  let parts = patternLower.split("*");
  let partsLength = parts.length;
  return reduceWithIndex(parts, true, (matches2, part, idx) => {
    if (matches2) {
      if (part === "") {
        return true;
      } else if (idx === 0) {
        return fileNameLower.startsWith(part);
      } else if (idx === (partsLength - 1 | 0)) {
        return fileNameLower.endsWith(part);
      } else {
        return fileNameLower.includes(part);
      }
    } else {
      return false;
    }
  });
}
function filterAndPaginate(lines, pattern2, maxResults) {
  let patternLower = pattern2.toLowerCase();
  let matchedFiles = lines.filter((filePath) => {
    let fileName2 = Nodepath__namespace.basename(filePath);
    return matchesPattern(fileName2, patternLower);
  });
  let truncated = matchedFiles.length > maxResults;
  let files = matchedFiles.slice(0, maxResults);
  return {
    files,
    totalResults: matchedFiles.length,
    truncated
  };
}
async function executeRipgrep2(rgPath, pattern2, searchPath, maxResults) {
  let args = buildRipgrepArgs2(searchPath);
  let result = await spawnResult(rgPath, args, void 0);
  if (result.TAG === "Ok") {
    let lines = result._0.stdout.trim().split("\n").filter((line) => line !== "");
    return {
      TAG: "Ok",
      _0: filterAndPaginate(lines, pattern2, maxResults)
    };
  }
  let match = result._0;
  let match$1 = match.code;
  if (match$1 === 1) {
    return {
      TAG: "Ok",
      _0: {
        files: [],
        totalResults: 0,
        truncated: false
      }
    };
  }
  return {
    TAG: "Error",
    _0: `Ripgrep failed: ` + match.stderr
  };
}
async function executeGitLsFiles(pattern2, searchPath, maxResults) {
  let result = await spawnResult("git", ["ls-files"], searchPath);
  if (result.TAG === "Ok") {
    let lines = result._0.stdout.trim().split("\n").filter((line) => line !== "");
    return {
      TAG: "Ok",
      _0: filterAndPaginate(lines, pattern2, maxResults)
    };
  }
  let match = result._0;
  let match$1 = match.code;
  if (match$1 === 1) {
    return {
      TAG: "Ok",
      _0: {
        files: [],
        totalResults: 0,
        truncated: false
      }
    };
  }
  return {
    TAG: "Error",
    _0: `Git ls-files failed: ` + match.stderr
  };
}
async function execute8(ctx2, input) {
  let searchPath = resolveSearchPath(ctx2.sourceRoot, input.path);
  let maxResults = getOr(input.max_results, 20);
  let rgPath = getRipgrepPath2();
  if (rgPath === void 0) {
    return await executeGitLsFiles(input.pattern, searchPath, maxResults);
  }
  let result = await executeRipgrep2(rgPath, input.pattern, searchPath, maxResults);
  if (result.TAG === "Ok") {
    return result;
  } else {
    return await executeGitLsFiles(input.pattern, searchPath, maxResults);
  }
}
var description8 = `Fast file name search tool that finds files matching a pattern.

WHEN TO USE THIS TOOL:
- Use when you need to find files by name pattern
- Great for locating specific files like "config.json" or "*.test.ts"
- Useful for finding all files with a specific extension or naming convention
- When you need to discover the file structure of a project
- Note: this tool only searches file names, not directory names. Use list_files to browse directories.

PARAMETERS:
- pattern (required): The filename pattern to search for (supports glob-like patterns)
- path (optional): Directory to search in (defaults to source root)
- max_results (optional): Maximum number of results to return (default: 20)

EXAMPLES:
- Find all config files: pattern="config"
- Find TypeScript test files: pattern="*.test.ts"
- Find files in specific directory: pattern="*.json", path="src/config"

OUTPUT:
Returns list of matching file paths.
Results are sorted by modification time (newest first).

LIMITATIONS:
- Results limited to max_results (default 20)
- Hidden files (starting with '.') are included
- Respects .gitignore when using git ls-files fallback
- Only finds files, not directories`;
var name10 = ToolNames.loadAgentInstructions;
var inputSchema9 = schema2((s2) => ({
  startPath: s2.m(option2(string2))
}));
var instructionFileSchema = schema2((s2) => ({
  content: s2.m(string2),
  fullPath: s2.m(string2)
}));
var outputSchema9 = array2(instructionFileSchema);
var agentsVariants = [
  "Agents.md",
  ".claude/Agents.md",
  "Agents.local.md"
];
var claudeVariants = [
  "CLAUDE.md",
  ".claude/CLAUDE.md",
  "CLAUDE.local.md"
];
async function findFileCaseInsensitive(dir, targetFileName) {
  try {
    let files = await Fs__namespace.promises.readdir(dir);
    let targetLower = targetFileName.toLowerCase();
    let found = files.find((file) => file.toLowerCase() === targetLower);
    if (found !== void 0) {
      return Nodepath__namespace.join(dir, found);
    } else {
      return;
    }
  } catch (exn) {
    return;
  }
}
async function loadIfExists(path) {
  let dir = Nodepath__namespace.dirname(path);
  let fileName2 = Nodepath__namespace.basename(path);
  let actualPath = await findFileCaseInsensitive(dir, fileName2);
  if (actualPath === void 0) {
    return;
  }
  try {
    let content = await Fs__namespace.promises.readFile(actualPath, "utf8");
    return {
      content,
      fullPath: actualPath
    };
  } catch (exn) {
    return;
  }
}
async function loadVariants(dir, variants) {
  let results = [];
  for (let i = 0, i_finish = variants.length; i < i_finish; ++i) {
    let variant = variants[i];
    let path = Nodepath__namespace.join(dir, variant);
    let file = await loadIfExists(path);
    if (file !== void 0) {
      results.push(file);
    }
  }
  return results;
}
async function findAtDirectory(dir) {
  let agentsFiles = await loadVariants(dir, agentsVariants);
  if (agentsFiles.length !== 0) {
    return agentsFiles;
  } else {
    return await loadVariants(dir, claudeVariants);
  }
}
async function walkUpDirectories(current, acc) {
  let parent = Nodepath__namespace.dirname(current);
  if (parent === current) {
    return acc;
  }
  let filesAtLevel = await findAtDirectory(current);
  let newAcc = acc.concat(filesAtLevel);
  return await walkUpDirectories(parent, newAcc);
}
async function execute9(ctx2, input) {
  let inputPath = getOr(input.startPath, ".");
  let msg = resolve(ctx2.sourceRoot, inputPath);
  if (msg.TAG !== "Ok") {
    return {
      TAG: "Error",
      _0: msg._0
    };
  }
  try {
    let startPath = toString(msg._0);
    let results = await walkUpDirectories(startPath, []);
    return {
      TAG: "Ok",
      _0: results
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg$1 = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to load agent instructions: ` + msg$1
    };
  }
}
var description9 = `Discovers and loads agent instruction files (Agents.md or CLAUDE.md) following Claude Code's discovery algorithm.

Parameters:
- startPath (optional): Starting directory for discovery - must be under source root. Defaults to "." (source root).

Discovery:
- Walks up from startPath to filesystem root
- At each level, checks for Agents.md variants (Agents.md, .claude/Agents.md, Agents.local.md)
- If any Agents variant found at a level, skips CLAUDE variants for that level
- Otherwise checks CLAUDE variants (CLAUDE.md, .claude/CLAUDE.md, CLAUDE.local.md)
- All matching files at each level are included
- Returns all found instruction files`;

// ../frontman-core/src/FrontmanCore__ToolRegistry.res.mjs
function coreTools() {
  return {
    tools: [
      {
        name: name4,
        description: description3,
        inputSchema: inputSchema3,
        outputSchema: outputSchema3,
        execute: execute3,
        visibleToAgent: true
      },
      {
        name: name6,
        description: description5,
        inputSchema: inputSchema5,
        outputSchema: outputSchema5,
        execute: execute5,
        visibleToAgent: true
      },
      {
        name: name5,
        description: description4,
        inputSchema: inputSchema4,
        outputSchema: outputSchema4,
        execute: execute4,
        visibleToAgent: true
      },
      {
        name: name7,
        description: description6,
        inputSchema: inputSchema6,
        outputSchema: outputSchema6,
        execute: execute6,
        visibleToAgent: true
      },
      {
        name: name10,
        description: description9,
        inputSchema: inputSchema9,
        outputSchema: outputSchema9,
        execute: execute9,
        visibleToAgent: false
      },
      {
        name: name2,
        description,
        inputSchema,
        outputSchema,
        execute,
        visibleToAgent: true
      },
      {
        name: name9,
        description: description8,
        inputSchema: inputSchema8,
        outputSchema: outputSchema8,
        execute: execute8,
        visibleToAgent: true
      },
      {
        name: name8,
        description: description7,
        inputSchema: inputSchema7,
        outputSchema: outputSchema7,
        execute: execute7,
        visibleToAgent: true
      },
      {
        name: name3,
        description: description2,
        inputSchema: inputSchema2,
        outputSchema: outputSchema2,
        execute: execute2,
        visibleToAgent: true
      }
    ]
  };
}
function addTools(registry, newTools) {
  return {
    tools: registry.tools.concat(newTools)
  };
}
function replaceByName(registry, replacement) {
  return {
    tools: registry.tools.map((m) => {
      if (m.name === replacement.name) {
        return replacement;
      } else {
        return m;
      }
    })
  };
}
function getToolByName(registry, name13) {
  return registry.tools.find((m) => m.name === name13);
}
function serializeTool(m) {
  return {
    name: m.name,
    description: m.description,
    inputSchema: toJSONSchema2(m.inputSchema),
    visibleToAgent: m.visibleToAgent
  };
}
function getToolDefinitions(registry) {
  return registry.tools.map(serializeTool);
}

// ../frontman-protocol/src/FrontmanProtocol__Relay.res.mjs
var remoteToolSchema = schema2((s2) => ({
  name: s2.m(string2),
  description: s2.m(string2),
  inputSchema: s2.m(json2),
  visibleToAgent: s2.m(bool2)
}));
var toolsResponseSchema = schema2((s2) => ({
  tools: s2.m(array2(remoteToolSchema)),
  serverInfo: s2.m(infoSchema),
  protocolVersion: s2.m(string2)
}));
var toolCallRequestSchema = schema2((s2) => ({
  name: s2.m(string2),
  arguments: s2.m(option2(dict2(json2)))
}));
var protocolVersion = "1.0";

// ../frontman-core/src/FrontmanCore__Server.res.mjs
async function executeTool(registry, ctx2, name13, $$arguments) {
  let toolModule = getToolByName(registry, name13);
  if (toolModule === void 0) {
    return {
      TAG: "ToolNotFound",
      _0: name13
    };
  }
  let toolCtx_projectRoot = ctx2.projectRoot;
  let toolCtx_sourceRoot = ctx2.sourceRoot;
  let toolCtx = {
    projectRoot: toolCtx_projectRoot,
    sourceRoot: toolCtx_sourceRoot
  };
  let inputJson = getOr($$arguments, {});
  try {
    let input = parseOrThrow2(inputJson, toolModule.inputSchema);
    let result = await toolModule.execute(toolCtx, input);
    if (result.TAG !== "Ok") {
      return {
        TAG: "Ok",
        _0: {
          content: [{
            type: "text",
            text: result._0
          }],
          isError: true
        }
      };
    }
    let outputJson = reverseConvertToJsonOrThrow2(result._0, toolModule.outputSchema);
    return {
      TAG: "Ok",
      _0: {
        content: [{
          type: "text",
          text: JSON.stringify(outputJson)
        }],
        isError: void 0
      }
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      return {
        TAG: "InvalidInput",
        _0: e._1.message
      };
    }
    let msg = getOr(flatMap(fromException(e), message2), "Unknown error");
    return {
      TAG: "ExecutionError",
      _0: msg
    };
  }
}
function resultToMCP(result) {
  switch (result.TAG) {
    case "Ok":
      return result._0;
    case "ToolNotFound":
      return {
        content: [{
          type: "text",
          text: `Tool not found: ` + result._0
        }],
        isError: true
      };
    case "InvalidInput":
      return {
        content: [{
          type: "text",
          text: `Invalid input: ` + result._0
        }],
        isError: true
      };
    case "ExecutionError":
      return {
        content: [{
          type: "text",
          text: `Execution error: ` + result._0
        }],
        isError: true
      };
  }
}
function getToolsResponse(registry, serverName, serverVersion) {
  return {
    tools: getToolDefinitions(registry),
    serverInfo: {
      name: serverName,
      version: serverVersion
    },
    protocolVersion
  };
}

// ../frontman-core/src/FrontmanCore__RequestHandlers.res.mjs
var resolveSourceLocationRequestSchema = schema2((s2) => ({
  componentName: s2.m(string2),
  file: s2.m(string2),
  line: s2.m(int2),
  column: s2.m(int2)
}));
var resolveSourceLocationResponseSchema = schema2((s2) => ({
  componentName: s2.m(string2),
  file: s2.m(string2),
  line: s2.m(int2),
  column: s2.m(int2)
}));
var errorResponseSchema = schema2((s2) => ({
  error: s2.m(string2),
  details: s2.m(option2(string2))
}));
function handleGetTools(registry, config) {
  let response = getToolsResponse(registry, config.serverName, config.serverVersion);
  let json3 = reverseConvertToJsonOrThrow2(response, toolsResponseSchema);
  let headers2 = Object.fromEntries([[
    "Content-Type",
    "application/json"
  ]]);
  return Response.json(json3, {
    headers: some(headers2)
  });
}
async function handleToolCall(registry, config, req) {
  let body = await req.json();
  let request;
  try {
    request = {
      TAG: "Ok",
      _0: parseOrThrow2(body, toolCallRequestSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      request = {
        TAG: "Error",
        _0: e._1.message
      };
    } else {
      throw e;
    }
  }
  if (request.TAG === "Ok") {
    let request$1 = request._0;
    let ctx_projectRoot = config.projectRoot;
    let ctx_sourceRoot = config.sourceRoot;
    let ctx2 = {
      projectRoot: ctx_projectRoot,
      sourceRoot: ctx_sourceRoot};
    let resultPromise = executeTool(registry, ctx2, request$1.name, request$1.arguments);
    let encoder = new TextEncoder();
    let stream = new Web__namespace.ReadableStream({
      start: (controller) => {
        $$catch(resultPromise.then((result) => {
          let mcpResult = resultToMCP(result);
          let match = mcpResult.isError;
          let eventData = match !== void 0 && match ? errorEvent(mcpResult) : resultEvent(mcpResult);
          controller.enqueue(encoder.encode(eventData));
          controller.close();
          return Promise.resolve();
        }), (error) => {
          let msg = getOr(flatMap(fromException(error), message2), "Unknown error");
          let errorResult_content2 = [{
            type: "text",
            text: `Tool execution failed: ` + msg
          }];
          let errorResult_isError2 = true;
          let errorResult2 = {
            content: errorResult_content2,
            isError: errorResult_isError2
          };
          controller.enqueue(encoder.encode(errorEvent(errorResult2)));
          controller.close();
          return Promise.resolve();
        });
      }
    });
    return new Response(stream, {
      headers: some(headers())
    });
  }
  let errorResult_content = [{
    type: "text",
    text: `Invalid request: ` + request._0
  }];
  let errorResult_isError = true;
  let errorResult = {
    content: errorResult_content,
    isError: errorResult_isError
  };
  let json3 = reverseConvertToJsonOrThrow2(errorResult, callToolResultSchema);
  return Response.json(json3, {
    status: 400
  });
}
async function handleResolveSourceLocation(sourceRoot, req) {
  let body = await req.json();
  let request;
  try {
    request = {
      TAG: "Ok",
      _0: parseOrThrow2(body, resolveSourceLocationRequestSchema)
    };
  } catch (raw_e) {
    let e = internalToException(raw_e);
    if (e.RE_EXN_ID === $$Error2) {
      request = {
        TAG: "Error",
        _0: e._1.message
      };
    } else {
      throw e;
    }
  }
  if (request.TAG === "Ok") {
    let request$1 = request._0;
    try {
      let sourceLocation_componentName = request$1.componentName;
      let sourceLocation_file = request$1.file;
      let sourceLocation_line = request$1.line;
      let sourceLocation_column = request$1.column;
      let sourceLocation = {
        componentName: sourceLocation_componentName,
        file: sourceLocation_file,
        line: sourceLocation_line,
        column: sourceLocation_column,
        componentProps: void 0,
        parent: void 0
      };
      let resolved = await Te(sourceLocation);
      let relativeFile = toRelativePath(sourceRoot, resolved.file);
      let responseJson_componentName = resolved.componentName;
      let responseJson_line = resolved.line;
      let responseJson_column = resolved.column;
      let responseJson = {
        componentName: responseJson_componentName,
        file: relativeFile,
        line: responseJson_line,
        column: responseJson_column
      };
      let json3 = reverseConvertToJsonOrThrow2(responseJson, resolveSourceLocationResponseSchema);
      let headers2 = Object.fromEntries([[
        "Content-Type",
        "application/json"
      ]]);
      return Response.json(json3, {
        headers: some(headers2)
      });
    } catch (raw_exn) {
      let exn = internalToException(raw_exn);
      let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
      let json$1 = reverseConvertToJsonOrThrow2({
        error: "Failed to resolve source location",
        details: msg
      }, errorResponseSchema);
      return Response.json(json$1, {
        status: 500
      });
    }
  } else {
    let json$2 = reverseConvertToJsonOrThrow2({
      error: `Invalid request: ` + request._0,
      details: void 0
    }, errorResponseSchema);
    return Response.json(json$2, {
      status: 400
    });
  }
}

// ../frontman-core/src/FrontmanCore__Middleware.res.mjs
function getSuffixRoutePrefix(path, basePath) {
  if (path === basePath) {
    return "";
  }
  let suffix = "/" + basePath;
  if (path.endsWith(suffix)) {
    return path.slice(0, path.length - suffix.length | 0);
  }
}
function isFrontmanRoute(pathname, basePath, method) {
  let prefix = "/" + basePath.toLowerCase();
  let path = pathname.toLowerCase();
  let isPrefixRoute = path === prefix || path.startsWith(prefix + "/");
  let isSuffixRoute = path.endsWith(prefix) || path.endsWith(prefix + "/");
  if (isPrefixRoute) {
    return true;
  } else if (method.toUpperCase() === "GET") {
    return isSuffixRoute;
  } else {
    return false;
  }
}
function getCanonicalRedirect(prefixPath, basePath) {
  let suffix = "/" + basePath;
  if (prefixPath === basePath) {
    return "/" + basePath;
  }
  if (prefixPath.endsWith(suffix)) {
    let stripped = prefixPath.slice(0, prefixPath.length - suffix.length | 0);
    let cleanPrefix = stripped === "" ? "" : stripped;
    let tmp = cleanPrefix === "" ? "/" + basePath : "/" + cleanPrefix + "/" + basePath;
    return tmp;
  }
  if (!prefixPath.startsWith(basePath + "/")) {
    return;
  }
  let rest = prefixPath.slice(basePath.length + 1 | 0);
  let tmp$1 = rest === "" ? "/" + basePath : "/" + rest + "/" + basePath;
  return tmp$1;
}
function buildEntrypointUrl(config, requestUrl, prefixPath) {
  let override = config.entrypointUrl;
  if (override !== void 0) {
    return override;
  }
  let url2 = new URL(requestUrl);
  let origin = url2.origin;
  let pagePath = prefixPath === "" ? "/" : "/" + prefixPath;
  return origin + pagePath;
}
function createMiddleware(config, registry) {
  let handlerConfig_projectRoot = config.projectRoot;
  let handlerConfig_sourceRoot = config.sourceRoot;
  let handlerConfig_serverName = config.serverName;
  let handlerConfig_serverVersion = config.serverVersion;
  let handlerConfig = {
    projectRoot: handlerConfig_projectRoot,
    sourceRoot: handlerConfig_sourceRoot,
    serverName: handlerConfig_serverName,
    serverVersion: handlerConfig_serverVersion
  };
  return async (req) => {
    let method = req.method.toLowerCase();
    let url2 = new URL(req.url);
    let pathname = url2.pathname;
    let pathSegments = pathname.split("/").filter((p2) => !isEmpty(p2));
    let originalPath = pathSegments.join("/");
    let path = originalPath.toLowerCase();
    let basePath = config.basePath.toLowerCase();
    let toolsPath = basePath + "/tools";
    let toolsCallPath = basePath + "/tools/call";
    let resolveSourceLocationPath = basePath + "/resolve-source-location";
    let isApiRoute = path === toolsPath || path === toolsCallPath || path === resolveSourceLocationPath;
    let suffixPrefix = isApiRoute ? void 0 : getSuffixRoutePrefix(path, basePath);
    let originalSuffixPrefix = map(suffixPrefix, (loweredPrefix) => {
      if (loweredPrefix === "") {
        return "";
      } else {
        return originalPath.slice(0, loweredPrefix.length);
      }
    });
    let isFrontmanRoute2 = isApiRoute || isSome(suffixPrefix);
    switch (method) {
      case "get":
        if (path === toolsPath) {
          return withCors(handleGetTools(registry, handlerConfig));
        }
        if (!isSome(suffixPrefix)) {
          return;
        }
        let prefixPath = getOrThrow(suffixPrefix);
        let canonicalPath = getCanonicalRedirect(prefixPath, basePath);
        if (canonicalPath !== void 0) {
          return new Response("", {
            status: 302,
            headers: some(Object.fromEntries([[
              "Location",
              canonicalPath
            ]]))
          });
        }
        let originalPrefix = getOrThrow(originalSuffixPrefix);
        let entrypointUrl = buildEntrypointUrl(config, req.url, originalPrefix);
        return withCors(serveWithEntrypoint(config, entrypointUrl));
      case "options":
        if (isFrontmanRoute2) {
          return handlePreflight();
        } else {
          return;
        }
      case "post":
        if (path === toolsCallPath) {
          return withCors(await handleToolCall(registry, handlerConfig, req));
        } else if (path === resolveSourceLocationPath) {
          return withCors(await handleResolveSourceLocation(config.sourceRoot, req));
        } else {
          return;
        }
      default:
        return;
    }
  };
}

// ../frontman-core/src/FrontmanCore__CircularBuffer.res.mjs
function make3(capacity) {
  return {
    data: make2(capacity, void 0),
    writeIndex: 0,
    count: 0,
    maxSize: capacity
  };
}
function push(buffer, entry) {
  buffer.data[buffer.writeIndex] = some(entry);
  return {
    data: buffer.data,
    writeIndex: mod_(buffer.writeIndex + 1 | 0, buffer.maxSize),
    count: min(buffer.count + 1 | 0, buffer.maxSize),
    maxSize: buffer.maxSize
  };
}
function toArray3(buffer) {
  let c2 = buffer.count;
  if (c2 === 0) {
    return [];
  }
  if (c2 < buffer.maxSize) {
    return filterMap(buffer.data.slice(0, buffer.count), (x) => x);
  }
  let tail = filterMap(buffer.data.slice(buffer.writeIndex, buffer.maxSize), (x) => x);
  let head = filterMap(buffer.data.slice(0, buffer.writeIndex), (x) => x);
  return tail.concat(head);
}
function length2(buffer) {
  return buffer.count;
}

// ../frontman-core/src/FrontmanCore__LogCapture.res.mjs
enableJson2();
function isBrowser() {
  return typeof window !== "undefined";
}
function getPatchedFlag() {
  return globalThis.__FRONTMAN_CORE_CONSOLE_PATCHED__;
}
function setPatchedFlag(_value) {
  globalThis.__FRONTMAN_CORE_CONSOLE_PATCHED__ = _value;
}
var logLevelSchema = union2([
  literal2("console"),
  literal2("build"),
  literal2("error")
]);
var consoleMethodSchema = union2([
  literal2("log"),
  literal2("info"),
  literal2("warn"),
  literal2("error"),
  literal2("debug")
]);
var logEntrySchema = schema2((s2) => ({
  timestamp: s2.m(string2),
  level: s2.m(logLevelSchema),
  message: s2.m(string2),
  attributes: s2.m(option2(json2)),
  resource: s2.m(option2(json2)),
  consoleMethod: s2.m(option2(consoleMethodSchema))
}));
var defaultConfig_stdoutPatterns = [
  "webpack",
  "turbopack",
  "Compiled",
  "Failed",
  "vite",
  "hmr",
  "error",
  "Error",
  "astro",
  "build"
];
var defaultConfig = {
  bufferCapacity: 1024,
  stdoutPatterns: defaultConfig_stdoutPatterns
};
function getGlobalInstanceOpt() {
  return globalThis.__FRONTMAN_CORE_INSTANCE__;
}
function setGlobalInstance(_state) {
  globalThis.__FRONTMAN_CORE_INSTANCE__ = _state;
}
function getOrCreateInstance(config) {
  let state = getGlobalInstanceOpt();
  if (state !== void 0) {
    return state;
  }
  let state_buffer = {
    contents: make3(config.bufferCapacity)
  };
  let state$1 = {
    buffer: state_buffer,
    config
  };
  setGlobalInstance(state$1);
  return state$1;
}
function getInstance() {
  let state = getGlobalInstanceOpt();
  if (state !== void 0) {
    return state;
  } else {
    return getOrCreateInstance(defaultConfig);
  }
}
function argsToString(args) {
  return args.map((arg) => {
    let match = typeof arg;
    if (match === "string") {
      return arg;
    } else if (match === "object") {
      if (arg instanceof Error) {
        return getOr(arg.stack, arg.message);
      } else {
        return getOr(JSON.stringify(arg), "null");
      }
    } else {
      return String(arg);
    }
  }).join(" ");
}
function stripAnsi(str) {
  return str.replace(/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g, "");
}
function addLog(state, level, message3, attributes, consoleMethod) {
  let cleanMessage = stripAnsi(message3).trim();
  if (cleanMessage === "") {
    return;
  }
  let entry_timestamp = new Date(Date.now()).toISOString();
  let entry = {
    timestamp: entry_timestamp,
    level,
    message: cleanMessage,
    attributes,
    resource: void 0,
    consoleMethod
  };
  state.buffer.contents = push(state.buffer.contents, entry);
}
function handleConsoleLog(state, args) {
  try {
    return addLog(state, "console", argsToString(args), void 0, "log");
  } catch (exn) {
    return;
  }
}
function handleConsoleWarn(state, args) {
  try {
    return addLog(state, "console", argsToString(args), void 0, "warn");
  } catch (exn) {
    return;
  }
}
function handleConsoleError(state, args) {
  try {
    return addLog(state, "console", argsToString(args), void 0, "error");
  } catch (exn) {
    return;
  }
}
function handleConsoleInfo(state, args) {
  try {
    return addLog(state, "console", argsToString(args), void 0, "info");
  } catch (exn) {
    return;
  }
}
function handleConsoleDebug(state, args) {
  try {
    return addLog(state, "console", argsToString(args), void 0, "debug");
  } catch (exn) {
    return;
  }
}
var interceptConsole = (function(state) {
  const originalLog = console.log.bind(console);
  const originalWarn = console.warn.bind(console);
  const originalError = console.error.bind(console);
  const originalInfo = console.info.bind(console);
  const originalDebug = console.debug.bind(console);
  console.log = (...args) => {
    handleConsoleLog(state, args);
    originalLog(...args);
  };
  console.warn = (...args) => {
    handleConsoleWarn(state, args);
    originalWarn(...args);
  };
  console.error = (...args) => {
    handleConsoleError(state, args);
    originalError(...args);
  };
  console.info = (...args) => {
    handleConsoleInfo(state, args);
    originalInfo(...args);
  };
  console.debug = (...args) => {
    handleConsoleDebug(state, args);
    originalDebug(...args);
  };
});
function handleStdoutWrite(state, message3) {
  try {
    let matchesPattern2 = state.config.stdoutPatterns.some((pattern2) => message3.includes(pattern2));
    if (matchesPattern2) {
      return addLog(state, "build", message3, void 0, void 0);
    } else {
      return;
    }
  } catch (exn) {
    return;
  }
}
function interceptStdout(_state) {
  (function(_state2) {
    const originalWrite = process.stdout.write.bind(process.stdout);
    process.stdout.write = (chunk, ...args) => {
      const message3 = typeof chunk === "string" ? chunk : chunk.toString();
      handleStdoutWrite(_state2, message3);
      return originalWrite(chunk, ...args);
    };
  })(_state);
}
function interceptUncaughtErrors(state) {
  process.on("uncaughtException", (error) => {
    try {
      let errorMessage = getOr(error.message, "Unknown error");
      let attributes = Object.fromEntries([
        [
          "stack",
          getOr(map(error.stack, (prim) => prim), null)
        ],
        [
          "name",
          error.name
        ]
      ]);
      return addLog(state, "error", errorMessage, attributes, void 0);
    } catch (exn) {
      return;
    }
  });
  process.on("unhandledRejection", (reason2) => {
    try {
      let reasonMessage = getOr(reason2.message, String.toString(reason2));
      let attributes = Object.fromEntries([[
        "stack",
        getOr(map(reason2.stack, (prim) => prim), null)
      ]]);
      return addLog(state, "error", reasonMessage, attributes, void 0);
    } catch (exn) {
      return;
    }
  });
}
function initialize(configOpt, param) {
  let config = defaultConfig;
  if (isBrowser()) {
    return;
  }
  let match = getPatchedFlag();
  if (match !== void 0 && match) {
    return;
  }
  setPatchedFlag(true);
  let state = getOrCreateInstance(config);
  interceptConsole(state);
  interceptStdout(state);
  interceptUncaughtErrors(state);
}
var regexCache = {
  pattern: void 0,
  regex: void 0
};
function getCompiledRegex(pattern2) {
  let cached = regexCache.pattern;
  if (cached !== void 0 && cached === pattern2) {
    let r = regexCache.regex;
    if (r !== void 0) {
      return r;
    }
    let regex = new RegExp(pattern2, "i");
    regexCache.regex = regex;
    return regex;
  }
  let regex$1 = new RegExp(pattern2, "i");
  regexCache.pattern = pattern2;
  regexCache.regex = regex$1;
  return regex$1;
}
function getLogs(pattern2, level, since, tail) {
  try {
    let state = getInstance();
    let allLogs = toArray3(state.buffer.contents);
    let logs = since !== void 0 ? allLogs.filter((entry) => new Date(entry.timestamp).getTime() >= since) : allLogs;
    let logs$1 = level !== void 0 ? logs.filter((entry) => entry.level === level) : logs;
    let logs$2;
    if (pattern2 !== void 0) {
      let regex = getCompiledRegex(pattern2);
      logs$2 = logs$1.filter((entry) => regex.test(entry.message));
    } else {
      logs$2 = logs$1;
    }
    if (tail === void 0) {
      return logs$2;
    }
    let len = logs$2.length;
    return logs$2.slice(max(0, len - tail | 0), len);
  } catch (exn) {
    return [];
  }
}

// src/tools/FrontmanVueCli__Tool__GetLogs.res.mjs
var inputSchema10 = schema2((s2) => ({
  pattern: s2.m(option2(string2)),
  level: s2.m(option2(logLevelSchema)),
  since: s2.m(option2(string2)),
  tail: s2.m(option2(int2))
}));
var outputSchema10 = schema2((s2) => ({
  logs: s2.m(array2(logEntrySchema)),
  totalMatched: s2.m(int2),
  bufferSize: s2.m(int2),
  hasMore: s2.m(bool2)
}));
async function execute10(_ctx, input) {
  try {
    let sinceTimestamp = map(input.since, (isoString) => new Date(isoString).getTime());
    let allMatchedLogs = getLogs(input.pattern, input.level, sinceTimestamp, void 0);
    let totalMatched = allMatchedLogs.length;
    let n = input.tail;
    let logs = n !== void 0 ? allMatchedLogs.slice(max(0, totalMatched - n | 0), totalMatched) : allMatchedLogs;
    let n$1 = input.tail;
    let hasMore = n$1 !== void 0 ? totalMatched > n$1 : false;
    let bufferSize = length2(getInstance().buffer.contents);
    return {
      TAG: "Ok",
      _0: {
        logs,
        totalMatched,
        bufferSize,
        hasMore
      }
    };
  } catch (raw_exn) {
    let exn = internalToException(raw_exn);
    let msg = getOr(flatMap(fromException(exn), message2), "Unknown error");
    return {
      TAG: "Error",
      _0: `Failed to retrieve logs: ` + msg
    };
  }
}
var name11 = "get_logs";
var description10 = `Retrieves dev server logs from rotating 1024-entry buffer.

Captures:
- Console output (console.log, warn, error, info, debug)
- Webpack build/HMR logs (compilation, errors, warnings)
- Uncaught exceptions with stack traces

Parameters:
- pattern (optional): JavaScript regex pattern to filter messages (case-insensitive)
  Examples: "error", "webpack.*hmr", "TypeError"
- level (optional): Filter by log type: "console", "build", or "error"
- since (optional): ISO 8601 timestamp - only return logs after this time
  Example: "2025-12-28T10:30:00.000Z"
- tail (optional): Limit to most recent N entries
  Example: 100 (returns last 100 matching logs)

Returns logs in chronological order (oldest first within buffer).`;

// src/tools/FrontmanVueCli__Tool__EditFile.res.mjs
function sleep(ms) {
  return new Promise((resolve4, param) => {
    setTimeout(() => resolve4(), ms);
  });
}
async function execute11(ctx2, input) {
  let beforeTimestamp = Date.now();
  let result = await execute2(ctx2, input);
  if (result.TAG !== "Ok") {
    return result;
  }
  let output = result._0;
  await sleep(800);
  let recentLogs = getLogs(void 0, "error", beforeTimestamp, void 0);
  let errorLogs = getLogs("error|Error|failed|Failed", void 0, beforeTimestamp, void 0);
  let seen = /* @__PURE__ */ new Set();
  recentLogs.forEach((entry) => {
    seen.add(entry.timestamp + "|" + entry.message);
  });
  let allErrors = recentLogs.concat(errorLogs.filter((entry) => !seen.has(entry.timestamp + "|" + entry.message)));
  if (allErrors.length === 0) {
    return {
      TAG: "Ok",
      _0: output
    };
  }
  let errorMessages = allErrors.slice(0, 5).map((entry) => entry.message).join("\n");
  let newrecord = { ...output };
  return {
    TAG: "Ok",
    _0: (newrecord.message = output.message + (`

Warning: Dev server errors detected after edit:
` + errorMessages), newrecord)
  };
}
var name12 = "edit_file";
var description11 = description2;
var inputSchema11 = inputSchema2;
var outputSchema11 = outputSchema2;

// src/FrontmanVueCli__ToolRegistry.res.mjs
var vuecliTools = [{
  name: name11,
  description: description10,
  inputSchema: inputSchema10,
  outputSchema: outputSchema10,
  execute: execute10,
  visibleToAgent: true
}];
function make4() {
  return replaceByName(addTools(coreTools(), vuecliTools), {
    name: name12,
    description: description11,
    inputSchema: inputSchema11,
    outputSchema: outputSchema11,
    execute: execute11,
    visibleToAgent: true
  });
}

// src/FrontmanVueCli__Middleware.res.mjs
function toMiddlewareConfig(config) {
  return {
    projectRoot: config.projectRoot,
    sourceRoot: config.sourceRoot,
    basePath: config.basePath,
    serverName: config.serverName,
    serverVersion: config.serverVersion,
    clientUrl: config.clientUrl,
    clientCssUrl: config.clientCssUrl,
    entrypointUrl: config.entrypointUrl,
    isLightTheme: config.isLightTheme,
    frameworkLabel: "Vue CLI"
  };
}
function createMiddleware2(config) {
  let registry = make4();
  let middlewareConfig = toMiddlewareConfig(config);
  return createMiddleware(middlewareConfig, registry);
}
var headersToDict = (function headersToDict2(headers2) {
  const dict3 = {};
  headers2.forEach(function(value, key) {
    dict3[key] = value;
  });
  return dict3;
});
var collectBody = (async function collectBody2(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
});
var pipeStreamToResponse = (async function pipeStreamToResponse2(stream, res) {
  const reader = stream.getReader();
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(value);
    }
  } finally {
    reader.releaseLock();
  }
});
function adaptMiddlewareToExpress(basePath, middleware) {
  return async (req, res, next) => {
    let reqUrl = getOr(fromNull(req.url), "/");
    let pathname = reqUrl.toLowerCase();
    let idx = pathname.indexOf("?");
    let pathOnly = idx !== -1 ? pathname.slice(0, idx) : pathname;
    let isFrontmanRoute2 = isFrontmanRoute(pathOnly, basePath, getOr(fromNull(req.method), "GET"));
    if (!isFrontmanRoute2) {
      return next();
    }
    let bodyBuffer = await collectBody(req);
    let host2 = getOr(req.headers["host"], "localhost");
    let url2 = `http://` + host2 + reqUrl;
    let method = getOr(fromNull(req.method), "GET");
    let headers2 = req.headers;
    let hasBody = bodyBuffer.length > 0;
    let body = hasBody ? some(bodyBuffer) : void 0;
    let webRequest = new Request(url2, {
      method,
      headers: some(headers2),
      body
    });
    let responseOption = await middleware(webRequest);
    if (responseOption === void 0) {
      return next();
    }
    res.statusCode = responseOption.status;
    let headerDict = headersToDict(responseOption.headers);
    res.writeHead(responseOption.status, headerDict);
    let stream = responseOption.body;
    if (stream !== null) {
      await pipeStreamToResponse(stream, res);
    }
    res.end();
  };
}
function servicePlugin(api, projectOptions) {
  api.configureDevServer((app, _devServer) => {
    initialize();
    let config = makeFromObject({});
    let middleware = createMiddleware2(config);
    let adaptedMiddleware = adaptMiddlewareToExpress(config.basePath, middleware);
    app.use((req, res, next) => {
      $$catch(adaptedMiddleware(req, res, next), (error) => {
        let msg = getOr(flatMap(fromException(error), message2), "Unknown error");
        console.error("Frontman middleware error:", msg);
        res.statusCode = 500;
        res.end("Internal Server Error");
        return Promise.resolve();
      });
    });
  });
  api.chainWebpack((config) => {
    let annotationCapturePath = Nodepath__namespace.resolve(__dirname, "../dist/annotation-capture.js");
    let entryPlugin = new Webpack__namespace.EntryPlugin(__dirname, annotationCapturePath, {
      name: null
    });
    config.plugin("frontman-annotation-capture").use(entryPlugin);
  });
}

// src/FrontmanVueCli.res.mjs
var Config;
var Middleware;
var Server;
var ToolRegistry;
var ServicePlugin;
var SSE;
var createMiddleware3 = createMiddleware2;
var makeConfig = makeFromObject;
var servicePlugin2 = servicePlugin;

exports.Config = Config;
exports.Middleware = Middleware;
exports.SSE = SSE;
exports.Server = Server;
exports.ServicePlugin = ServicePlugin;
exports.ToolRegistry = ToolRegistry;
exports.createMiddleware = createMiddleware3;
exports.makeConfig = makeConfig;
exports.servicePlugin = servicePlugin2;
