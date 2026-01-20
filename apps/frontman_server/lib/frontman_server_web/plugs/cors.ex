defmodule FrontmanServerWeb.Plugs.CORS do
  @moduledoc """
  CORS plug for cross-origin API requests.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_origin(conn)

    conn
    |> put_resp_header("access-control-allow-origin", origin)
    |> put_resp_header("access-control-allow-credentials", "true")
    |> put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> handle_preflight()
  end

  defp get_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin] -> origin
      _ -> "*"
    end
  end

  defp handle_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(204, "")
    |> halt()
  end

  defp handle_preflight(conn), do: conn
end
