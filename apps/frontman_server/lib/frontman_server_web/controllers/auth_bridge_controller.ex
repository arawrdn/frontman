defmodule FrontmanServerWeb.AuthBridgeController do
  use FrontmanServerWeb, :controller

  def show(conn, _params) do
    render(conn, :show)
  end
end
