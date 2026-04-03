module Dialog = Bindings__UI__Dialog
module Button = Bindings__UI__Button
module CookieAuthHelp = Client__CookieAuthHelp

@react.component
let make = (~loginUrl: string, ~markWelcomeShown: unit => unit) => {
  React.useEffect0(() => {
    markWelcomeShown()
    None
  })

  let browser = CookieAuthHelp.currentBrowser()

  let (title, description, steps) = switch browser {
  | Safari =>
    (
      "Safari is blocking the Frontman sign-in cookie.",
      "Frontman signs you in on a different Frontman domain, and Safari often blocks that cookie by default in embedded experiences.",
      [
        "Open Safari Settings (or Preferences) and go to Privacy.",
        "Turn off ‘Prevent cross-site tracking’. If ‘Block all cookies’ is on, turn that off too.",
        "Reload this page, then sign in again.",
      ],
    )
  | Chrome =>
    (
      "Your browser may be blocking Frontman's sign-in cookie.",
      "Chrome privacy settings or extensions can block the cross-site cookie Frontman needs to finish signing you in.",
      [
        "Open Chrome Settings → Privacy and security → Third-party cookies.",
        "Allow third-party cookies, or add an exception for Frontman on this site.",
        "Reload this page, then sign in again.",
      ],
    )
  | Firefox =>
    (
      "Your browser may be blocking Frontman's sign-in cookie.",
      "Firefox Enhanced Tracking Protection can stop the cross-site cookie Frontman uses during sign-in.",
      [
        "Open Firefox Settings → Privacy & Security.",
        "Turn off Enhanced Tracking Protection for this site, or allow cross-site cookies in your Custom settings.",
        "Reload this page, then sign in again.",
      ],
    )
  | Edge =>
    (
      "Your browser may be blocking Frontman's sign-in cookie.",
      "Edge privacy or cookie settings can block the cross-site cookie Frontman needs during sign-in.",
      [
        "Open Edge Settings → Cookies and site permissions → Manage and delete cookies and site data.",
        "Turn off ‘Block third-party cookies’, or allow Frontman for this site.",
        "Reload this page, then sign in again.",
      ],
    )
  | Unknown =>
    (
      "Frontman needs cross-site cookies to finish signing you in.",
      "This browser appears to be blocking the Frontman sign-in cookie while the app is embedded on another site.",
      [
        "Allow third-party or cross-site cookies for Frontman in your browser settings.",
        "Reload this page after changing the setting.",
        "Try signing in again.",
      ],
    )
  }

  <Dialog.Dialog open_={true} onOpenChange={_ => ()}>
    <Dialog.DialogContent
      className="sm:max-w-lg max-w-lg border-zinc-700 bg-zinc-900 p-0"
      showCloseButton={false}>
      <div className="px-8 py-10 text-center">
        <div className="mx-auto mb-6">
          <Client__FrontmanLogo size=48 />
        </div>
        <Dialog.DialogTitle className="text-xl font-bold text-zinc-100">
          {React.string(title)}
        </Dialog.DialogTitle>
        <Dialog.DialogDescription className="mt-3 text-sm leading-relaxed text-zinc-400">
          {React.string(description)}
        </Dialog.DialogDescription>

        <div className="mt-8 rounded-xl border border-zinc-800 bg-zinc-950/60 p-5 text-left">
          <ol className="list-decimal space-y-3 pl-5 text-sm leading-relaxed text-zinc-300">
            {steps
            ->Array.map(step =>
              <li key={step}>
                {React.string(step)}
              </li>
            )
            ->React.array}
          </ol>
        </div>

        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
          <Button.Button
            variant=#secondary
            className="sm:min-w-44"
            onClick={_ => CookieAuthHelp.continueToLogin(~loginUrl)}>
            {React.string("Sign in again")}
          </Button.Button>
          <Button.Button
            variant=#outline
            className="sm:min-w-44"
            onClick={_ => WebAPI.Location.reload(WebAPI.Global.location)}>
            {React.string("Reload after enabling")}
          </Button.Button>
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
