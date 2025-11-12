//@ts-ignore
import {main, config} from './Figma.res.mjs'

export default defineContentScript({
  matches: config.matches,
  runAt: "document_start",
  world: "MAIN",
  main() {
    main()
  },
})