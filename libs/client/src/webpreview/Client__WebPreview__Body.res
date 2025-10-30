@react.component
let make = (~url)=> {
    <div className="flex-1">
      <iframe
        className={"size-full"}
        sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-presentation"
        src={url}
        title="Preview"
      />
    </div>
}