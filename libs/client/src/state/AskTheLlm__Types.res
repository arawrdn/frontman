type state = {
    url: string,
    messages: array<string>,
}

type action = 
    | SetUrl(string)
    | AddMessage(string)