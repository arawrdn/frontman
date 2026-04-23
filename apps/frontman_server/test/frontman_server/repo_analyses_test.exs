defmodule FrontmanServer.RepoAnalysesTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import Mox

  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.RepoAnalyses
  alias FrontmanServer.RepoAnalyses.RepoAnalysis

  setup :verify_on_exit!

  setup do
    original_github_client = Application.get_env(:frontman_server, :repo_analyses_github_client)
    Application.put_env(:frontman_server, :repo_analyses_github_client, MockGitHubClient)

    on_exit(fn ->
      if original_github_client do
        Application.put_env(
          :frontman_server,
          :repo_analyses_github_client,
          original_github_client
        )
      else
        Application.delete_env(:frontman_server, :repo_analyses_github_client)
      end
    end)

    scope = user_scope_fixture()
    %{scope: scope}
  end

  describe "analyze_repository/3" do
    test "persists an immutable analysis run", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"
      commit_sha = sha("a")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "main" ->
        {:ok, %{name: "main", commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, Jason.encode!(%{"image" => "ghcr.io/acme/dev:latest"})}
      end)

      assert {:ok, %RepoAnalysis{} = analysis} =
               RepoAnalyses.analyze_repository(scope, repo_name)

      assert analysis.provider == "github"
      assert analysis.repo_name == repo_name
      assert analysis.requested_ref == nil
      assert analysis.resolved_ref_kind == "branch"
      assert analysis.resolved_ref_name == "main"
      assert analysis.resolved_commit_sha == commit_sha
      assert analysis.devcontainer_path == ".devcontainer/devcontainer.json"
      assert analysis.devcontainer_raw == %{"image" => "ghcr.io/acme/dev:latest"}
      assert analysis.user_id == scope.user.id

      persisted = Repo.get!(RepoAnalysis, analysis.id)
      assert persisted.id == analysis.id
      assert persisted.inserted_at == analysis.inserted_at
    end

    test "persists requested_ref for explicit ref input", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"
      commit_sha = sha("b")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "release" ->
        {:ok, %{name: "release", commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, Jason.encode!(%{"name" => "release"})}
      end)

      assert {:ok, analysis} =
               RepoAnalyses.analyze_repository(scope, repo_name, ref: "release")

      assert analysis.requested_ref == "release"
      assert analysis.resolved_ref_kind == "branch"
      assert analysis.resolved_ref_name == "release"
      assert analysis.resolved_commit_sha == commit_sha
    end

    test "ignores unsupported options and only forwards domain opts", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"
      commit_sha = sha("c")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "main" ->
        {:ok, %{name: "main", commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, Jason.encode!(%{"name" => "main"})}
      end)

      assert {:ok, analysis} =
               RepoAnalyses.analyze_repository(scope, repo_name,
                 ref: "main",
                 github_client: :should_not_be_used,
                 unexpected: :ignored
               )

      assert analysis.requested_ref == "main"
      assert analysis.resolved_commit_sha == commit_sha
    end

    test "returns a changeset error when analyzer returns malformed commit sha", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"
      malformed_commit_sha = "not-a-sha"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "main" ->
        {:ok, %{name: "main", commit_sha: malformed_commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^malformed_commit_sha ->
        {:ok, Jason.encode!(%{"name" => "broken"})}
      end)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoAnalyses.analyze_repository(scope, repo_name)

      assert %{resolved_commit_sha: ["has invalid format"]} = errors_on(changeset)
      assert analysis_count_for_scope(scope) == 0
    end

    test "returns :invalid_repo_name for invalid repository format", %{scope: scope} do
      assert {:error, :invalid_repo_name} =
               RepoAnalyses.analyze_repository(scope, "owner-only")

      assert analysis_count_for_scope(scope) == 0
    end

    test "returns :no_github_oauth_token when scope has no token", %{scope: scope} do
      assert {:error, :no_github_oauth_token} =
               RepoAnalyses.analyze_repository(scope, "owner/repo")

      assert analysis_count_for_scope(scope) == 0
    end

    test "maps repository 404 to :repo_not_found", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/missing"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:error, :not_found}
      end)

      assert {:error, :repo_not_found} =
               RepoAnalyses.analyze_repository(scope, repo_name)

      assert analysis_count_for_scope(scope) == 0
    end

    test "maps ref 404 to :ref_not_found", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "does-not-exist" ->
        {:error, :not_found}
      end)
      |> expect(:resolve_tag, fn ^token, ^repo_name, "does-not-exist" ->
        {:error, :not_found}
      end)

      assert {:error, :ref_not_found} =
               RepoAnalyses.analyze_repository(scope, repo_name, ref: "does-not-exist")

      assert analysis_count_for_scope(scope) == 0
    end

    test "maps GitHub unauthorized response to :unauthorized", %{scope: scope} do
      token = put_github_token(scope)
      repo_name = "owner/repo"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:error, :unauthorized}
      end)

      assert {:error, :unauthorized} =
               RepoAnalyses.analyze_repository(scope, repo_name)

      assert analysis_count_for_scope(scope) == 0
    end
  end

  defp analysis_count_for_scope(scope) do
    RepoAnalysis
    |> where([analysis], analysis.user_id == ^scope.user.id)
    |> Repo.aggregate(:count)
  end

  defp put_github_token(scope) do
    access_token = "github-access-token"
    {:ok, _token} = Providers.upsert_oauth_token(scope, "github", access_token, nil, nil)
    access_token
  end

  defp sha(char), do: String.duplicate(char, 40)
end
