//@ts-ignore
import {main, config} from './DevServer.res.mjs'

export default defineContentScript({
  runAt: "document_idle",
  matches: config.matches,
  main() {
    main()
  },
})