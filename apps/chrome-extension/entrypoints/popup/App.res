%%raw("import './App.css'")

@module("@/assets/react.svg") external reactLogo: string = "default"
@module("/wxt.svg") external wxtLogo: string = "default"

@react.component
let make = () => {
  let (count, setCount) = React.useState(() => 0)

  <div>
    <div>
      <a href="https://wxt.dev" target="_blank">
        <img src={wxtLogo} className="logo" alt="WXT logo" />
      </a>
      <a href="https://react.dev" target="_blank">
        <img src={reactLogo} className="logo react" alt="React logo" />
      </a>
    </div>
    <h1>
      {React.string("WXT + React")}
    </h1>
    <div className="card">
      <button onClick={_ => setCount(count => count + 1)}>
        {React.string(`count is ${count->Int.toString}`)}
      </button>
      <p>
        {React.string("Edit ")}
        <code>
          {React.string("src/App.tsx")}
        </code>
        {React.string(" and save to test HMR")}
      </p>
    </div>
    <p className="read-the-docs">
      {React.string("Click on the WXT and React logos to learn more")}
    </p>
  </div>
}

