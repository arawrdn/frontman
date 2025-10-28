open DOMAPI

include HTMLElement.Impl({type t = htmliFrameElement})

@send
external getSVGDocument: htmliFrameElement => document = "getSVGDocument"

@get
external contentDocument: htmliFrameElement => Null.t<document> = "contentDocument"

@get
external contentWindow: htmliFrameElement => Null.t<WebAPI.DOMAPI.window> = "contentWindow"