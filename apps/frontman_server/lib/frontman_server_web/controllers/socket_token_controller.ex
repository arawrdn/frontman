# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.SocketTokenController do
  use FrontmanServerWeb, :controller

  def show(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        session_token = conn.assigns[:user_session_token] || get_session(conn, :user_token)
        token = Phoenix.Token.sign(conn, "user socket", session_token)
        json(conn, %{token: token})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end
end
