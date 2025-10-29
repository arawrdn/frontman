// ---
// title: Chatbot
// description: An example of how to use the AI Elements to build a chatbot.
// ---

// An example of how to use the AI Elements to build a chatbot.

// <Preview path="chatbot" type="block" className="p-0" />

// ## Tutorial

// Let's walk through how to build a chatbot using AI Elements and AI SDK. Our example will include reasoning, web search with citations, and a model picker.

// ### Setup

// First, set up a new Next.js repo and cd into it by running the following command (make sure you choose to use Tailwind the project setup):

// ```bash title="Terminal"
// npx create-next-app@latest ai-chatbot && cd ai-chatbot
// ```

// Run the following command to install AI Elements. This will also set up shadcn/ui if you haven't already configured it:

// ```bash title="Terminal"
// npx ai-elements@latest
// ```

// Now, install the AI SDK dependencies:

// ```package-install
// npm i ai @ai-sdk/react zod
// ```

// In order to use the providers, let's configure an AI Gateway API key. Create a `.env.local` in your root directory and navigate [here](https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fai%2Fapi-keys&title=Get%20your%20AI%20Gateway%20key) to create a token, then paste it in your `.env.local`.

// We're now ready to start building our app!

// ### Client

// In your `app/page.tsx`, replace the code with the file below.

// Here, we use the `PromptInput` component with its compound components to build a rich input experience with file attachments, model picker, and action menu. The input component uses the new `PromptInputMessage` type for handling both text and file attachments.

// The whole chat lives in a `Conversation`. We switch on `message.parts` and render the respective part within `Message`, `Reasoning`, and `Sources`. We also use `status` from `useChat` to stream reasoning tokens, as well as render `Loader`.

// ```tsx title="app/page.tsx"
// 'use client';

// import {
//   Conversation,
//   ConversationContent,
//   ConversationScrollButton,
// } from '@/components/ai-elements/conversation';
// import { Message, MessageContent } from '@/components/ai-elements/message';
// import {
//   PromptInput,
//   PromptInputActionAddAttachments,
//   PromptInputActionMenu,
//   PromptInputActionMenuContent,
//   PromptInputActionMenuTrigger,
//   PromptInputAttachment,
//   PromptInputAttachments,
//   PromptInputBody,
//   PromptInputButton,
//   type PromptInputMessage,
//   PromptInputModelSelect,
//   PromptInputModelSelectContent,
//   PromptInputModelSelectItem,
//   PromptInputModelSelectTrigger,
//   PromptInputModelSelectValue,
//   PromptInputSubmit,
//   PromptInputTextarea,
//   PromptInputFooter,
//   PromptInputTools,
// } from '@/components/ai-elements/prompt-input';
// import { Action, Actions } from '@/components/ai-elements/actions';
// import { Fragment, useState } from 'react';
// import { useChat } from '@ai-sdk/react';
// import { Response } from '@/components/ai-elements/response';
// import { CopyIcon, GlobeIcon, RefreshCcwIcon } from 'lucide-react';
// import {
//   Source,
//   Sources,
//   SourcesContent,
//   SourcesTrigger,
// } from '@/components/ai-elements/sources';
// import {
//   Reasoning,
//   ReasoningContent,
//   ReasoningTrigger,
// } from '@/components/ai-elements/reasoning';
// import { Loader } from '@/components/ai-elements/loader';

// const models = [
//   {
//     name: 'GPT 4o',
//     value: 'openai/gpt-4o',
//   },
//   {
//     name: 'Deepseek R1',
//     value: 'deepseek/deepseek-r1',
//   },
// ];

// const ChatBotDemo = () => {
//   const [input, setInput] = useState('');
//   const [model, setModel] = useState<string>(models[0].value);
//   const [webSearch, setWebSearch] = useState(false);
//   const { messages, sendMessage, status, regenerate } = useChat();

//   const handleSubmit = (message: PromptInputMessage) => {
//     const hasText = Boolean(message.text);
//     const hasAttachments = Boolean(message.files?.length);

//     if (!(hasText || hasAttachments)) {
//       return;
//     }

//     sendMessage(
//       { 
//         text: message.text || 'Sent with attachments',
//         files: message.files 
//       },
//       {
//         body: {
//           model: model,
//           webSearch: webSearch,
//         },
//       },
//     );
//     setInput('');
//   };

//   return (
//     <div className="max-w-4xl mx-auto p-6 relative size-full h-screen">
//       <div className="flex flex-col h-full">
//         <Conversation className="h-full">
//           <ConversationContent>
//             {messages.map((message) => (
//               <div key={message.id}>
//                 {message.role === 'assistant' && message.parts.filter((part) => part.type === 'source-url').length > 0 && (
//                   <Sources>
//                     <SourcesTrigger
//                       count={
//                         message.parts.filter(
//                           (part) => part.type === 'source-url',
//                         ).length
//                       }
//                     />
//                     {message.parts.filter((part) => part.type === 'source-url').map((part, i) => (
//                       <SourcesContent key={`${message.id}-${i}`}>
//                         <Source
//                           key={`${message.id}-${i}`}
//                           href={part.url}
//                           title={part.url}
//                         />
//                       </SourcesContent>
//                     ))}
//                   </Sources>
//                 )}
//                 {message.parts.map((part, i) => {
//                   switch (part.type) {
//                     case 'text':
//                       return (
//                         <Fragment key={`${message.id}-${i}`}>
//                           <Message from={message.role}>
//                             <MessageContent>
//                               <Response>
//                                 {part.text}
//                               </Response>
//                             </MessageContent>
//                           </Message>
//                           {message.role === 'assistant' && i === messages.length - 1 && (
//                             <Actions className="mt-2">
//                               <Action
//                                 onClick={() => regenerate()}
//                                 label="Retry"
//                               >
//                                 <RefreshCcwIcon className="size-3" />
//                               </Action>
//                               <Action
//                                 onClick={() =>
//                                   navigator.clipboard.writeText(part.text)
//                                 }
//                                 label="Copy"
//                               >
//                                 <CopyIcon className="size-3" />
//                               </Action>
//                             </Actions>
//                           )}
//                         </Fragment>
//                       );
//                     case 'reasoning':
//                       return (
//                         <Reasoning
//                           key={`${message.id}-${i}`}
//                           className="w-full"
//                           isStreaming={status === 'streaming' && i === message.parts.length - 1 && message.id === messages.at(-1)?.id}
//                         >
//                           <ReasoningTrigger />
//                           <ReasoningContent>{part.text}</ReasoningContent>
//                         </Reasoning>
//                       );
//                     default:
//                       return null;
//                   }
//                 })}
//               </div>
//             ))}
//             {status === 'submitted' && <Loader />}
//           </ConversationContent>
//           <ConversationScrollButton />
//         </Conversation>

//         <PromptInput onSubmit={handleSubmit} className="mt-4" globalDrop multiple>
//           <PromptInputHeader>
//             <PromptInputAttachments>
//               {(attachment) => <PromptInputAttachment data={attachment} />}
//             </PromptInputAttachments>
//           </PromptInputHeader>
//           <PromptInputBody>
//             <PromptInputTextarea
//               onChange={(e) => setInput(e.target.value)}
//               value={input}
//             />
//           </PromptInputBody>
//           <PromptInputFooter>
//             <PromptInputTools>
//               <PromptInputActionMenu>
//                 <PromptInputActionMenuTrigger />
//                 <PromptInputActionMenuContent>
//                   <PromptInputActionAddAttachments />
//                 </PromptInputActionMenuContent>
//               </PromptInputActionMenu>
//               <PromptInputButton
//                 variant={webSearch ? 'default' : 'ghost'}
//                 onClick={() => setWebSearch(!webSearch)}
//               >
//                 <GlobeIcon size={16} />
//                 <span>Search</span>
//               </PromptInputButton>
//               <PromptInputModelSelect
//                 onValueChange={(value) => {
//                   setModel(value);
//                 }}
//                 value={model}
//               >
//                 <PromptInputModelSelectTrigger>
//                   <PromptInputModelSelectValue />
//                 </PromptInputModelSelectTrigger>
//                 <PromptInputModelSelectContent>
//                   {models.map((model) => (
//                     <PromptInputModelSelectItem key={model.value} value={model.value}>
//                       {model.name}
//                     </PromptInputModelSelectItem>
//                   ))}
//                 </PromptInputModelSelectContent>
//               </PromptInputModelSelect>
//             </PromptInputTools>
//             <PromptInputSubmit disabled={!input && !status} status={status} />
//           </PromptInputFooter>
//         </PromptInput>
//       </div>
//     </div>
//   );
// };

// export default ChatBotDemo;
// ```

// ### Server

// Create a new route handler `app/api/chat/route.ts` and paste in the following code. We're using `perplexity/sonar` for web search because by default the model returns search results. We also pass `sendSources` and `sendReasoning` to `toUIMessageStreamResponse` in order to receive as parts on the frontend. The handler now also accepts file attachments from the client.

// ```ts title="app/api/chat/route.ts"
// import { streamText, UIMessage, convertToModelMessages } from 'ai';

// // Allow streaming responses up to 30 seconds
// export const maxDuration = 30;

// export async function POST(req: Request) {
//   const {
//     messages,
//     model,
//     webSearch,
//   }: { 
//     messages: UIMessage[]; 
//     model: string; 
//     webSearch: boolean;
//   } = await req.json();

//   const result = streamText({
//     model: webSearch ? 'perplexity/sonar' : model,
//     messages: convertToModelMessages(messages),
//     system:
//       'You are a helpful assistant that can answer questions and help with tasks',
//   });

//   // send sources and reasoning back to the client
//   return result.toUIMessageStreamResponse({
//     sendSources: true,
//     sendReasoning: true,
//   });
// }
// ```

// You now have a working chatbot app with file attachment support! The chatbot can handle both text and file inputs through the action menu. Feel free to explore other components like [`Tool`](/elements/components/tool) or [`Task`](/elements/components/task) to extend your app, or view the other examples.

module Conversation = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: (~className: string, ~children: React.element) => React.element = "Conversation"
}

module ConversationContent = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: (~children: React.element) => React.element = "ConversationContent"
}

module ConversationScrollButton = {
    @react.component @module("@/components/ai-elements/conversation")
    external make: unit => React.element = "ConversationScrollButton"
}

module Loader = {
    @react.component @module("@/components/ai-elements/loader")
    external make: unit => React.element = "Loader"
}

module Sources = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~children: React.element) => React.element = "Sources"
}

module SourcesTrigger = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~count: int) => React.element = "SourcesTrigger"
}

module SourcesContent = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~key: string, ~children: React.element) => React.element = "SourcesContent"
}

module Source = {
    @react.component @module("@/components/ai-elements/sources")
    external make: (~key: string, ~href: string, ~title: string) => React.element = "Source"
}

module Message = {
    @react.component @module("@/components/ai-elements/message")
    external make: (~from: string, ~children: React.element) => React.element = "Message"
}

module MessageContent = {
    @react.component @module("@/components/ai-elements/message")
    external make: (~children: React.element) => React.element = "MessageContent"
}

module Response = {
    @react.component @module("@/components/ai-elements/response")
    external make: (~children: React.element) => React.element = "Response"
}

module Actions = {
    @react.component @module("@/components/ai-elements/actions")
    external make: (~className: string, ~children: React.element) => React.element = "Actions"
}

module Action = {
    @react.component @module("@/components/ai-elements/actions")
    external make: (~onClick: unit => unit, ~label: string, ~children: React.element) => React.element = "Action"
}

module Reasoning = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: (~key: string=?, ~className: string=?, ~isStreaming: bool=?, ~children: React.element) => React.element = "Reasoning"
}

module ReasoningTrigger = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: unit => React.element = "ReasoningTrigger"
}

module ReasoningContent = {
    @react.component @module("@/components/ai-elements/reasoning")
    external make: (~children: React.element) => React.element = "ReasoningContent"
}

module PromptInput = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onSubmit: unit => unit, ~className: string, ~children: React.element, ~globalDrop: bool, ~multiple: bool) => React.element = "PromptInput"
}

module PromptInputHeader = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputHeader"
}

module PromptInputAttachments = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: 'a => React.element) => React.element = "PromptInputAttachments"
}

module PromptInputAttachment = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~data: 'a) => React.element = "PromptInputAttachment"
}

module PromptInputBody = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputBody"
}

module PromptInputTextarea = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onChange: ReactEvent.Form.t => unit, ~value: string) => React.element = "PromptInputTextarea"
}

module PromptInputFooter = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputFooter"
}

module PromptInputTools = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputTools"
}

module PromptInputActionMenu = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputActionMenu"
}

module PromptInputActionMenuTrigger = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputActionMenuTrigger"
}

module PromptInputActionMenuContent = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputActionMenuContent"
}

module PromptInputActionAddAttachments = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputActionAddAttachments"
}

module PromptInputButton = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~variant: string, ~onClick: unit => unit, ~children: React.element) => React.element = "PromptInputButton"
}

module PromptInputModelSelect = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~onValueChange: string => unit, ~value: string, ~children: React.element) => React.element = "PromptInputModelSelect"
}

module PromptInputModelSelectTrigger = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputModelSelectTrigger"
}

module PromptInputModelSelectValue = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: unit => React.element = "PromptInputModelSelectValue"
}

module PromptInputModelSelectContent = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~children: React.element) => React.element = "PromptInputModelSelectContent"
}

module PromptInputModelSelectItem = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~key: string, ~value: string, ~children: React.element) => React.element = "PromptInputModelSelectItem"
}

module PromptInputSubmit = {
    @react.component @module("@/components/ai-elements/prompt-input")
    external make: (~disabled: bool, ~status: string) => React.element = "PromptInputSubmit"
}

// Web Preview components
type consoleLogLevel = [#log | #warn | #error]

type consoleLog = {
  level: consoleLogLevel,
  message: string,
  timestamp: Js.Date.t,
}

module WebPreview = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~defaultUrl: string=?, ~onUrlChange: string => unit=?, ~children: React.element) => React.element = "WebPreview"
}

module WebPreviewNavigation = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~children: React.element) => React.element = "WebPreviewNavigation"
}

module WebPreviewNavigationButton = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~onClick: unit => unit=?, ~disabled: bool=?, ~tooltip: string=?, ~children: React.element) => React.element = "WebPreviewNavigationButton"
}

module WebPreviewUrl = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~value: string=?, ~onChange: ReactEvent.Form.t => unit=?, ~onKeyDown: ReactEvent.Keyboard.t => unit=?) => React.element = "WebPreviewUrl"
}

module WebPreviewBody = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~loading: React.element=?, ~src: string=?) => React.element = "WebPreviewBody"
}

module WebPreviewConsole = {
    @react.component @module("@/components/ai-elements/web-preview")
    external make: (~className: string=?, ~logs: array<consoleLog>=?, ~children: React.element=?) => React.element = "WebPreviewConsole"
}