defmodule FrontmanServerWeb.OAuthController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.UserAuth

  import FrontmanServerWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode when action in [:link_request, :link_callback, :unlink]

  def request(conn, %{"provider" => provider}) do
    redirect_uri = url(~p"/auth/callback")
    {:ok, url} = Accounts.get_oauth_authorization_url(provider, redirect_uri)
    redirect(conn, external: url)
  end

  def callback(conn, %{"code" => code}) do
    {:ok, user} = Accounts.authenticate_with_oauth(code)

    conn
    |> put_flash(:info, "Welcome!")
    |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
  end

  def callback(conn, %{"error" => "access_denied"}) do
    conn
    |> put_flash(:error, "Sign in was cancelled.")
    |> redirect(to: ~p"/users/log-in")
  end

  def link_request(%{assigns: %{current_scope: %{user: _user}}} = conn, %{"provider" => provider}) do
    redirect_uri = url(~p"/auth/link/callback")
    state = generate_state_token()
    {:ok, url} = Accounts.get_oauth_authorization_url(provider, redirect_uri, state)

    conn
    |> put_session(:oauth_state, state)
    |> redirect(external: url)
  end

  def link_callback(%{assigns: %{current_scope: %{user: user}}} = conn, %{"code" => code, "state" => state}) do
    ^state = get_session(conn, :oauth_state)
    {:ok, identity} = Accounts.link_oauth_provider(user, code)

    conn
    |> delete_session(:oauth_state)
    |> put_flash(:info, "#{provider_display_name(identity.provider)} connected successfully.")
    |> redirect(to: ~p"/users/settings")
  end

  def link_callback(conn, %{"error" => "access_denied"}) do
    conn
    |> delete_session(:oauth_state)
    |> put_flash(:error, "Connection was cancelled.")
    |> redirect(to: ~p"/users/settings")
  end

  def unlink(%{assigns: %{current_scope: %{user: user}}} = conn, %{"provider" => provider}) do
    {:ok, _identity} = Accounts.unlink_oauth_provider(user, provider)

    conn
    |> put_flash(:info, "#{provider_display_name(provider)} disconnected.")
    |> redirect(to: ~p"/users/settings")
  end

  defp generate_state_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp provider_display_name("github"), do: "GitHub"
  defp provider_display_name("google"), do: "Google"
end
