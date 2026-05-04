# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.IntegrationsController do
  use FrontmanServerWeb, :controller

  require Logger

  @packages ~w(@frontman-ai/vite @frontman-ai/nextjs @frontman-ai/astro)
  @hop_by_hop_request_headers ~w(
    accept-encoding
    connection
    content-length
    host
    keep-alive
    proxy-authenticate
    proxy-authorization
    te
    trailer
    transfer-encoding
    upgrade
  )
  @hop_by_hop_response_headers ~w(
    connection
    content-encoding
    content-length
    keep-alive
    proxy-authenticate
    proxy-authorization
    te
    trailer
    transfer-encoding
    upgrade
  )

  # Simple in-memory cache: {versions_map, fetched_at_unix}
  @cache_ttl_ms :timer.minutes(30)

  def latest_versions(conn, _params) do
    versions = get_cached_versions()
    json(conn, %{versions: versions})
  end

  def daytona_preview_proxy(conn, %{"path" => path}) do
    config = Application.get_env(:frontman_server, :daytona_preview_spike, [])

    with {:ok, base_url} <- configured_daytona_base_url(config),
         {:ok, body, conn} <- read_daytona_proxy_body(conn),
         {:ok, response} <- request_daytona_preview(conn, base_url, path, body, config) do
      send_daytona_proxy_response(conn, response)
    else
      {:error, :missing_base_url} ->
        conn
        |> put_status(:service_unavailable)
        |> text("DAYTONA_PREVIEW_URL is required for the Daytona preview spike proxy")

      {:error, reason} ->
        Logger.warning("Daytona preview spike proxy failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_gateway)
        |> text("Daytona preview spike proxy failed")
    end
  end

  def daytona_preview_proxy(conn, _params), do: daytona_preview_proxy(conn, %{"path" => []})

  # -- private --

  defp configured_daytona_base_url(config) do
    case Keyword.get(config, :url) do
      url when is_binary(url) and url != "" -> {:ok, String.trim_trailing(url, "/")}
      nil -> {:error, :missing_base_url}
    end
  end

  defp read_daytona_proxy_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        read_raw_daytona_proxy_body(conn)

      params when map_size(params) > 0 ->
        {:ok, Jason.encode!(params), conn}

      %{} ->
        read_raw_daytona_proxy_body(conn)
    end
  end

  defp read_raw_daytona_proxy_body(conn) do
    case Plug.Conn.read_body(conn,
           length: 10_000_000,
           read_length: 1_000_000,
           read_timeout: 15_000
         ) do
      {:ok, body, conn} -> {:ok, body, conn}
      {:more, _partial, _conn} -> {:error, :body_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_daytona_preview(conn, base_url, path, body, config) do
    Req.request(
      method: conn.method,
      url: daytona_target_url(base_url, path, conn.query_string),
      body: daytona_proxy_body(body),
      headers: daytona_request_headers(conn, config),
      redirect: false,
      receive_timeout: 30_000
    )
  end

  defp daytona_target_url(base_url, path, "") do
    [base_url, Enum.join(path, "/")]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp daytona_target_url(base_url, path, query_string) do
    daytona_target_url(base_url, path, "") <> "?" <> query_string
  end

  defp daytona_proxy_body(""), do: nil
  defp daytona_proxy_body(body), do: body

  defp daytona_request_headers(conn, config) do
    conn.req_headers
    |> Enum.reject(fn {name, _value} -> name in @hop_by_hop_request_headers end)
    |> put_daytona_header("x-daytona-skip-preview-warning", "true")
    |> put_daytona_header("x-forwarded-host", daytona_forwarded_host(conn))
    |> maybe_put_daytona_token(Keyword.get(config, :token))
  end

  defp maybe_put_daytona_token(headers, token) when is_binary(token) and token != "" do
    put_daytona_header(headers, "x-daytona-preview-token", token)
  end

  defp maybe_put_daytona_token(headers, _token), do: headers

  defp put_daytona_header(headers, name, value) do
    [{name, value} | Enum.reject(headers, fn {header_name, _value} -> header_name == name end)]
  end

  defp daytona_forwarded_host(conn) do
    case conn.port do
      80 -> conn.host
      443 -> conn.host
      port -> conn.host <> ":" <> Integer.to_string(port)
    end
  end

  defp send_daytona_proxy_response(conn, %Req.Response{
         status: status,
         headers: headers,
         body: body
       }) do
    conn = Enum.reduce(headers, conn, &put_daytona_proxy_response_header/2)

    conn
    |> put_status(status)
    |> send_resp(status, daytona_response_body(body))
  end

  defp put_daytona_proxy_response_header({name, _value}, conn)
       when name in @hop_by_hop_response_headers do
    conn
  end

  defp put_daytona_proxy_response_header({name, values}, conn) when is_list(values) do
    Enum.reduce(values, conn, fn value, acc -> put_resp_header(acc, name, to_string(value)) end)
  end

  defp put_daytona_proxy_response_header({name, value}, conn) do
    put_resp_header(conn, name, to_string(value))
  end

  defp daytona_response_body(body) when is_binary(body), do: body
  defp daytona_response_body(body), do: Jason.encode!(body)

  defp get_cached_versions do
    case :persistent_term.get({__MODULE__, :cache}, nil) do
      {versions, fetched_at} when is_map(versions) ->
        if System.monotonic_time(:millisecond) - fetched_at < @cache_ttl_ms do
          versions
        else
          fetch_and_cache()
        end

      _ ->
        fetch_and_cache()
    end
  end

  defp fetch_and_cache do
    # Double-check: another request may have refreshed the cache while we waited
    case :persistent_term.get({__MODULE__, :cache}, nil) do
      {versions, fetched_at} when is_map(versions) ->
        if System.monotonic_time(:millisecond) - fetched_at < @cache_ttl_ms do
          versions
        else
          do_fetch_and_cache()
        end

      _ ->
        do_fetch_and_cache()
    end
  end

  defp do_fetch_and_cache do
    versions =
      @packages
      |> Task.async_stream(&fetch_latest_version/1,
        timeout: :timer.seconds(10),
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {pkg, version}}, acc -> Map.put(acc, pkg, version)
        {:exit, _reason}, acc -> acc
      end)

    # Only cache when at least one package resolved successfully.
    # On total failure (all nil / empty map), skip caching so the next
    # request retries immediately instead of serving stale nils for 30 min.
    has_valid_version = Enum.any?(versions, fn {_pkg, v} -> v != nil end)

    if has_valid_version do
      :persistent_term.put({__MODULE__, :cache}, {versions, System.monotonic_time(:millisecond)})
    end

    versions
  end

  defp fetch_latest_version(package) do
    url = "https://registry.npmjs.org/#{package}/latest"

    case Req.get(url, headers: [{"accept", "application/json"}]) do
      {:ok, %Req.Response{status: 200, body: %{"version" => version}}} ->
        {package, version}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("npm registry returned #{status} for #{package}: #{inspect(body)}")
        {package, nil}

      {:error, reason} ->
        Logger.warning("Failed to fetch npm version for #{package}: #{inspect(reason)}")
        {package, nil}
    end
  end
end
