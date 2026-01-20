defmodule FrontmanServerWeb.UserSocket do
  use Phoenix.Socket

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope

  ## Channels
  channel("tasks", FrontmanServerWeb.TasksChannel)
  channel("task:*", FrontmanServerWeb.TaskChannel)

  @impl true
  def connect(_params, socket, connect_info) do
    # Always allow socket connection - auth checked on channel join
    case get_authenticated_scope(connect_info) do
      {:ok, scope} -> {:ok, assign(socket, :scope, scope)}
      :error -> {:ok, socket}
    end
  end

  defp get_authenticated_scope(connect_info) do
    with %{"user_token" => token} <- connect_info[:session],
         {user, _} <- Accounts.get_user_by_session_token(token) do
      {:ok, Scope.for_user(user)}
    else
      _ -> :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.FrontmanServerWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
