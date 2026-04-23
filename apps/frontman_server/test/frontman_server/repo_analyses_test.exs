defmodule FrontmanServer.RepoAnalysesTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import Mox

  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.RepoAnalyses
  alias FrontmanServer.RepoAnalyses.RepoAnalysis
  alias FrontmanServer.Test.Support.RepoAnalyses.GitHubClientHelpers

  setup :verify_on_exit!

  setup do
    scope = user_scope_fixture()

    GitHubClientHelpers.setup_mock_client()

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
               RepoAnalyses.analyze_repository(scope, repo_name, nil)

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
               RepoAnalyses.analyze_repository(scope, repo_name, "release")

      assert analysis.requested_ref == "release"
      assert analysis.resolved_ref_kind == "branch"
      assert analysis.resolved_ref_name == "release"
      assert analysis.resolved_commit_sha == commit_sha
    end

    test "supports explicit github client and requested ref", %{scope: scope} do
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
               RepoAnalyses.analyze_repository(scope, repo_name, "main")

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
               RepoAnalyses.analyze_repository(scope, repo_name, nil)

      assert %{resolved_commit_sha: ["has invalid format"]} = errors_on(changeset)
      assert analysis_count_for_scope(scope) == 0
    end

    test "returns :invalid_repo_name for invalid repository format", %{scope: scope} do
      assert {:error, :invalid_repo_name} =
               RepoAnalyses.analyze_repository(scope, "owner-only", nil)

      assert analysis_count_for_scope(scope) == 0
    end

    test "returns :no_github_oauth_token when scope has no token", %{scope: scope} do
      assert {:error, :no_github_oauth_token} =
               RepoAnalyses.analyze_repository(scope, "owner/repo", nil)

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
               RepoAnalyses.analyze_repository(scope, repo_name, nil)

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
               RepoAnalyses.analyze_repository(scope, repo_name, "does-not-exist")

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
               RepoAnalyses.analyze_repository(scope, repo_name, nil)

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
