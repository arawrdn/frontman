//@ts-ignore
import {main} from './Background.res.mjs'

export default defineBackground({
    type: "module",
    persistent: true,
    main() {
        main()
    }
})