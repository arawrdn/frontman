// Radix UI Tabs bindings
// Usage:
// <RadixUI__Tabs.Root defaultValue="tab1">
//   <RadixUI__Tabs.List>
//     <RadixUI__Tabs.Trigger value="tab1">{React.string("One")}</RadixUI__Tabs.Trigger>
//     <RadixUI__Tabs.Trigger value="tab2">{React.string("Two")}</RadixUI__Tabs.Trigger>
//   </RadixUI__Tabs.List>
//   <RadixUI__Tabs.Content value="tab1">{React.string("Tab one content")}</RadixUI__Tabs.Content>
//   <RadixUI__Tabs.Content value="tab2">{React.string("Tab two content")}</RadixUI__Tabs.Content>
// </RadixUI__Tabs.Root>

type orientation = [#horizontal | #vertical]
type dir = [#ltr | #rtl]
type activationMode = [#automatic | #manual]

module Root = {
  @module("@radix-ui/react-tabs") @react.component
  external make: (
    ~asChild: bool=?,
    ~defaultValue: string=?,
    ~value: string=?,
    ~onValueChange: string => unit=?,
    ~orientation: orientation=?,
    ~dir: dir=?,
    ~activationMode: activationMode=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Root"
}

module List = {
  @module("@radix-ui/react-tabs") @react.component
  external make: (
    ~asChild: bool=?,
    ~loop: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "List"
}

module Trigger = {
  @module("@radix-ui/react-tabs") @react.component
  external make: (
    ~asChild: bool=?,
    ~value: string,
    ~disabled: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Trigger"
}

module Content = {
  @module("@radix-ui/react-tabs") @react.component
  external make: (
    ~asChild: bool=?,
    ~value: string,
    ~forceMount: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Content"
}
