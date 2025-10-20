@module("./Client__Button.module.css")
external styles: {"button": string} = "default"

@genType
let make = props =>
  <button
    {...props}
    className={styles["button"]}
  />
