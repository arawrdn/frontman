defmodule FrontmanServerWeb.AuthBridgeControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  describe "GET /auth-bridge" do
    test "renders the bridge page", %{conn: conn} do
      conn = get(conn, ~p"/auth-bridge")

      assert html_response(conn, 200) =~ "Completing sign in"
    end
  end
end
