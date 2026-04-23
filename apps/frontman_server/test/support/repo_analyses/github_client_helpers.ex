defmodule FrontmanServer.Test.Support.RepoAnalyses.GitHubClientHelpers do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]

  alias FrontmanServer.Test.Support.RepoAnalyses.StaticGitHubClient

  @app :frontman_server
  @config_key :repo_analyses_github_client

  @doc """
  Set the repo analyses client for the current test and restore the previous value
  when the test exits.
  """
  def setup_client(client_module) do
    original_client = Application.fetch_env!(@app, @config_key)
    Application.put_env(@app, @config_key, client_module)

    on_exit(fn ->
      Application.put_env(@app, @config_key, original_client)
    end)

    :ok
  end

  @doc """
  Set the repo analyses client to the deterministic static test client.
  """
  def setup_static_client(_context \\ nil) do
    setup_client(StaticGitHubClient)
    :ok
  end

  @doc """
  Set the repo analyses client to the mock implementation for expectation tests.
  """
  def setup_mock_client(_context \\ nil) do
    setup_client(MockGitHubClient)
    :ok
  end
end
