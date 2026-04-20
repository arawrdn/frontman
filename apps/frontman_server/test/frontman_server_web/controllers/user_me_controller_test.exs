defmodule FrontmanServerWeb.UserMeControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  describe "GET /api/user/me" do
    test "accepts bearer auth using a socket token", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/api/socket-token")
      %{"token" => socket_token} = json_response(conn, 200)

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("authorization", "Bearer #{socket_token}")
        |> get(~p"/api/user/me")

      assert json_response(conn, 200)["email"] == user.email
    end
  end
end
