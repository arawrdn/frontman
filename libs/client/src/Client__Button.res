@module("./Client__Button.module.css")
external styles: {"button": string} = "default"

let make = props =>
  <button
    {...props}
    className={styles["button"]}
  />
