// Next.js Middleware Module
// This module provides middleware functionality for Next.js applications
module Request = {
  type t

  @get external url: t => string = "url"
  @get external method: t => string = "method"
  @get external headers: t => WebAPI.FetchAPI.headers = "headers"
}

module Response = {
  type t

  @module("next/server") @scope("NextResponse")
  external next: unit => t = "next"

  @module("next/server") @scope("NextResponse")
  external redirect: string => t = "redirect"

  @module("next/server") @scope("NextResponse")
  external rewrite: string => t = "rewrite"

  @module("next/server") @scope("NextResponse")
  external json: 'a => t = "json"
}

module Config = {
  type matcher =
    | String(string)
    | Array(array<string>)

  type t = {matcher: matcher}

  let make = (~matcher) => {
    {matcher: matcher}
  }
}

// Middleware handler type
type handler = Request.t => promise<Response.t>

let getPathname = (url: string): string => {
  let urlObj = WebAPI.URL.make(~url)
  urlObj.pathname
}

// Main middleware that handles /ask-the-llm route
let middleware: handler = req => {
  let pathname = getPathname(Request.url(req))

  if pathname == "/ask-the-llm" {
    Response.json({
      "message": "Ask the LLM endpoint",
      "path": pathname,
      "timestamp": %raw(`new Date().toISOString()`),
    })->Promise.resolve
  } else {
    Response.next()->Promise.resolve
  }
}

// Configuration that matches the /ask-the-llm route
let config = Config.make(~matcher=Array(["/ask-the-llm"]))
