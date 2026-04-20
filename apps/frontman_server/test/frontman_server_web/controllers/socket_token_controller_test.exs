defmodule FrontmanServerWeb.SocketTokenControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts

  describe "GET /api/socket-token" do
    test "returns a websocket token backed by the current session token", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      session_token = get_session(conn, :user_token)
      conn = get(conn, ~p"/api/socket-token")

      assert %{"token" => socket_token} = json_response(conn, 200)

      assert {:ok, ^session_token} =
               Phoenix.Token.verify(FrontmanServerWeb.Endpoint, "user socket", socket_token)
    end

    test "returns unauthorized when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/socket-token")

      assert json_response(conn, 401) == %{"error" => "Not authenticated"}
    end

    test "signed socket token is rejected after logout", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      conn = get(conn, ~p"/api/socket-token")
      %{"token" => socket_token} = json_response(conn, 200)

      user_token = get_session(conn, :user_token)
      Accounts.delete_user_session_token(user_token)

      assert {:ok, socket} =
               FrontmanServerWeb.UserSocket.connect(
                 %{"token" => socket_token},
                 %Phoenix.Socket{},
                 %{}
               )

      refute Map.has_key?(socket.assigns, :scope)
    end
  end
end
