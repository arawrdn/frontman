module AIElements = Bindings__AIElements
module Icons = Bindings__RadixUI__Icons
module AISDK = Bindings__AISDK__React

type model = {
  name: string,
  value: string,
}

let models = [
  {name: "GPT 4o", value: "openai/gpt-4o"},
  {name: "Deepseek R1", value: "deepseek/deepseek-r1"},
]

@react.component
let make = () => {
  let (input, setInput) = React.useState(() => "")
  let (model, setModel) = React.useState(() => Array.getUnsafe(models, 0).value)
  let (webSearch, setWebSearch) = React.useState(() => false)

  let {messages, sendMessage, status, regenerate} = AISDK.useChat()

  let handleSubmit = (message: {"text": string, "files": option<array<WebAPI.FileAPI.file>>}) => {
    let hasText = message["text"] !== ""
    let hasAttachments = message["files"]->Option.mapOr(false, files => files->Array.length > 0)

    if hasText || hasAttachments {
      sendMessage(
        {
          "text": Some(message["text"]),
          "files": message["files"],
        },
        {
          "body": {
            "model": model,
            "webSearch": webSearch,
          },
        },
      )
      setInput(_ => "")
    }
  }

  <div className="flex flex-col h-full">
    <AIElements.Conversation className="flex-grow overflow-hidden">
      <AIElements.ConversationContent>
        {messages
        ->Array.mapWithIndex((message, i) => {
          let messageId = message.id

          // Filter source-url parts
          let sourceUrls = message.parts->Array.filter(part => part.type_ === "source-url")

          <div key={messageId}>
            {message.role === "assistant" && sourceUrls->Array.length > 0
              ? <AIElements.Sources>
                  <AIElements.SourcesTrigger count={sourceUrls->Array.length} />
                  {sourceUrls
                  ->Array.mapWithIndex((part, j) => {
                    part.url->Option.mapOr(
                      React.null,
                      url =>
                        <AIElements.SourcesContent key={`${messageId}-${j->Int.toString}`}>
                          <AIElements.Source
                            key={`${messageId}-${j->Int.toString}`} href={url} title={url}
                          />
                        </AIElements.SourcesContent>,
                    )
                  })
                  ->React.array}
                </AIElements.Sources>
              : React.null}
            {message.parts
            ->Array.mapWithIndex((part, j) => {
              let partKey = `${messageId}-${j->Int.toString}`

              if part.type_ === "text" {
                part.text->Option.mapOr(
                  React.null,
                  text =>
                    <React.Fragment key={partKey}>
                      <AIElements.Message from={message.role}>
                        <AIElements.MessageContent>
                          <AIElements.Response> {React.string(text)} </AIElements.Response>
                        </AIElements.MessageContent>
                      </AIElements.Message>
                      {message.role === "assistant" && i === messages->Array.length - 1
                        ? <AIElements.Actions className="mt-2">
                            <AIElements.Action onClick={() => regenerate()} label="Retry">
                              <Icons.ReloadIcon style={{"width": "12px", "height": "12px"}} />
                            </AIElements.Action>
                            <AIElements.Action
                              onClick={() => {
                                let _ =
                                  WebAPI.Global.navigator.clipboard->WebAPI.Clipboard.writeText(
                                    text,
                                  )
                              }}
                              label="Copy"
                            >
                              <Icons.CopyIcon style={{"width": "12px", "height": "12px"}} />
                            </AIElements.Action>
                          </AIElements.Actions>
                        : React.null}
                    </React.Fragment>,
                )
              } else if part.type_ === "reasoning" {
                part.text->Option.mapOr(
                  React.null,
                  text =>
                    <AIElements.Reasoning
                      key={partKey}
                      className="w-full"
                      isStreaming={status === "streaming" &&
                      j === message.parts->Array.length - 1 &&
                      message.id ===
                        messages
                        ->Array.get(messages->Array.length - 1)
                        ->Option.mapOr("", m => m.id)}
                    >
                      <AIElements.ReasoningTrigger />
                      <AIElements.ReasoningContent>
                        {React.string(text)}
                      </AIElements.ReasoningContent>
                    </AIElements.Reasoning>,
                )
              } else {
                React.null
              }
            })
            ->React.array}
          </div>
        })
        ->React.array}
        {status === "submitted" ? <AIElements.Loader /> : React.null}
      </AIElements.ConversationContent>
      <AIElements.ConversationScrollButton />
    </AIElements.Conversation>
    <AIElements.PromptInput
      onSubmit={() => handleSubmit({"text": input, "files": None})}
      className=""
      globalDrop={true}
      multiple={true}
    >
      <AIElements.PromptInputHeader>
        <AIElements.PromptInputAttachments>
          {attachment => <AIElements.PromptInputAttachment data={attachment} />}
        </AIElements.PromptInputAttachments>
      </AIElements.PromptInputHeader>
      <AIElements.PromptInputBody>
        <AIElements.PromptInputTextarea
          onChange={e => {
            let target = ReactEvent.Form.target(e)
            setInput(_ => target["value"])
          }}
          value={input}
        />
      </AIElements.PromptInputBody>
      <AIElements.PromptInputFooter>
        <AIElements.PromptInputTools>
          <AIElements.PromptInputActionMenu>
            <AIElements.PromptInputActionMenuTrigger />
            <AIElements.PromptInputActionMenuContent>
              <AIElements.PromptInputActionAddAttachments />
            </AIElements.PromptInputActionMenuContent>
          </AIElements.PromptInputActionMenu>
          <AIElements.PromptInputButton
            variant={webSearch ? "default" : "ghost"} onClick={() => setWebSearch(prev => !prev)}
          >
            <Icons.GlobeIcon style={{"width": "16px", "height": "16px"}} />
            <span> {React.string("Search")} </span>
          </AIElements.PromptInputButton>
          <AIElements.PromptInputModelSelect
            onValueChange={value => setModel(_ => value)} value={model}
          >
            <AIElements.PromptInputModelSelectTrigger>
              <AIElements.PromptInputModelSelectValue />
            </AIElements.PromptInputModelSelectTrigger>
            <AIElements.PromptInputModelSelectContent>
              {models
              ->Array.map(model => {
                <AIElements.PromptInputModelSelectItem key={model.value} value={model.value}>
                  {React.string(model.name)}
                </AIElements.PromptInputModelSelectItem>
              })
              ->React.array}
            </AIElements.PromptInputModelSelectContent>
          </AIElements.PromptInputModelSelect>
        </AIElements.PromptInputTools>
        <AIElements.PromptInputSubmit
          disabled={input === "" && status !== "streaming"} status={status}
        />
      </AIElements.PromptInputFooter>
    </AIElements.PromptInput>
  </div>
}
