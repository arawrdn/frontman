//@ts-ignore
import {main, config} from './DevServer.res.mjs'

export default defineContentScript({
  runAt: "document_start",
  matches: config.matches,
  main() {
    main()
  },
})