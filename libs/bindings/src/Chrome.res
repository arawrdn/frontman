// Port type for runtime.connect
type port<'message> = {
  name: string,
  disconnect: unit => unit,
  postMessage: 'message => unit,
}
module Runtime = {
  type tab = {id: int}
  type messageSender = {tab: tab}
  type sendResponseFn<'response> = 'response => unit

  type connectInfo = {name?: string}

  module Connect = {
    // Listen for incoming port connections
    let addConnectListener: (port<'message> => unit) => unit = %raw(`
      function(callback) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onConnect) {
          chrome.runtime.onConnect.addListener(callback);
        } else {
          console.error('chrome.runtime.onConnect is not available');
        }
      }
    `)
    let addConnectExternalListener: (string, port<'message> => unit) => unit = %raw(`
      function(extensionId, callback) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onConnectExternal) {
          chrome.runtime.onConnectExternal.addListener(callback);
        } else {
          console.error('chrome.runtime.onConnectExternal is not available');
        }
      }
    `)

    // Remove listener for incoming port connections
    let removeConnectListener: (port<'message> => unit) => unit = %raw(`
      function(callback) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onConnect) {
          chrome.runtime.onConnect.removeListener(callback);
        } else {
          console.error('chrome.runtime.onConnect is not available');
        }
      }
    `)
    let removeConnectExternalListener: (string, port<'message> => unit) => unit = %raw(`
      function(extensionId, callback) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onConnectExternal) {
          chrome.runtime.onConnectExternal.removeListener(callback);
        } else {
          console.error('chrome.runtime.onConnectExternal is not available');
        }
      }
    `)
    // Connect to the extension
    let connect: option<connectInfo> => port<'message> = %raw(`
      function(connectInfo) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.connect) {
          return chrome.runtime.connect(connectInfo);
        } else {
          console.error('chrome.runtime.connect is not available');
          return null;
        }
      }
    `)

    // Connect to another extension
    let connectExternal: (string, option<connectInfo>) => port<'message> = %raw(`
      function(extensionId, connectInfo) {
        if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.connect) {
          return chrome.runtime.connect(extensionId, connectInfo);
        } else {
          console.error('chrome.runtime.connect is not available');
          return null;
        }
      }
    `)

    // Add listener to port's onMessage event
    let addMessageListener: (port<'message>, 'message => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onMessage) {
          port.onMessage.addListener(callback);
        } else {
          console.error('port.onMessage is not available');
        }
      }
    `)

    // Remove listener from port's onMessage event
    let removeMessageListener: (port<'message>, 'message => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onMessage) {
          port.onMessage.removeListener(callback);
        } else {
          console.error('port.onMessage is not available');
        }
      }
    `)

    // Add listener to port's onDisconnect event
    let addDisconnectListener: (port<'message>, port<'message> => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onDisconnect) {
          port.onDisconnect.addListener(callback);
        } else {
          console.error('port.onDisconnect is not available');
        }
      }
    `)

    // Remove listener from port's onDisconnect event
    let removeDisconnectListener: (port<'message>, port<'message> => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onDisconnect) {
          port.onDisconnect.removeListener(callback);
        } else {
          console.error('port.onDisconnect is not available');
        }
      }
    `)
  }

  let addMessageExternalListener: (
    ('message, messageSender, sendResponseFn<'response>) => unit
  ) => unit = %raw(`
  function(callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessageExternal) {
      chrome.runtime.onMessageExternal.addListener(callback);
    } else {
      console.error('chrome.runtime.onMessageExternal is not available');
    }
  }
`)
  let removeMessageExternalListener: (
    ('message, messageSender, sendResponseFn<'response>) => unit
  ) => unit = %raw(`
  function(callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessageExternal) {
      chrome.runtime.onMessageExternal.removeListener(callback);
    }
  }
`)
  let addMessageListener: (
    ('message, messageSender, sendResponseFn<'response>) => unit
  ) => unit = %raw(`
  function(callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
      chrome.runtime.onMessage.addListener(callback);
    } else {
      console.error('chrome.runtime.onMessage is not available');
    }
  }
`)
  let removeMessageListener: (
    ('message, messageSender, sendResponseFn<'response>) => unit
  ) => unit = %raw(`
  function(callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
      chrome.runtime.onMessage.removeListener(callback);
    }
  }
`)
  let sendMessageExternal: (string, 'data, 'response => unit) => unit = %raw(`
  function(extensionId, data, callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      chrome.runtime.sendMessage(extensionId, data, callback);
    } else {
      console.error('chrome.runtime.sendMessage is not available');
    }
  }
`)
  let sendMessage: ('data, 'response => unit) => unit = %raw(`
  function(data, callback) {
    if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.sendMessage) {
      chrome.runtime.sendMessage(data, callback);
    } else {
      console.error('chrome.runtime.sendMessage is not available');
    }
  }
`)
}

module Tabs = {
  type t = {
    id: int,
    url: string,
    title: string,
    favIconUrl: string,
    status: string,
    pinned: bool,
    windowId: int,
  }

  let sendMessage: (int, 'data, 'response => unit) => unit = %raw(`
    function(tabId, data, callback) {
      if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.sendMessage) {
        chrome.tabs.sendMessage(tabId, data, callback);
      } else {
        console.error('chrome.tabs.sendMessage is not available');
      }
    }
  `)

  // Connect to a specific tab
  let connect: (int, option<Runtime.connectInfo>) => port<'message> = %raw(`
    function(tabId, connectInfo) {
      if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.connect) {
        return chrome.tabs.connect(tabId, connectInfo);
      } else {
        console.error('chrome.tabs.connect is not available');
        return null;
      }
    }
  `)

  // Get current tab
  let getCurrent: ('tab => unit) => unit = %raw(`
    function(callback) {
      if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.getCurrent) {
        chrome.tabs.getCurrent(callback);
      } else {
        console.error('chrome.tabs.getCurrent is not available');
      }
    }
  `)
}

module Port = {
  let addMessageListener: (port<'message>, 'message => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onMessage) {
          port.onMessage.addListener(callback);
        } else {
          console.error('port.onMessage is not available');
        }
      }
    `)
  let removeMessageListener: (port<'message>, 'message => unit) => unit = %raw(`
      function(port, callback) {
        if (port && port.onMessage) {
          port.onMessage.removeListener(callback);
        } else {
          console.error('port.onMessage is not available');
        }
      }
    `)
}
