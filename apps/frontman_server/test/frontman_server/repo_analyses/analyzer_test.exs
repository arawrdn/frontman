defmodule FrontmanServer.RepoAnalyses.AnalyzerTest do
  use ExUnit.Case, async: true

  import Mox

  alias FrontmanServer.RepoAnalyses.Analyzer

  setup :verify_on_exit!

  describe "analyze_repository/4" do
    test "resolves default branch when ref is omitted" do
      token = "github-token"
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
        {:ok, Jason.encode!(%{"image" => "node:20"})}
      end)

      assert {:ok, analysis} =
               Analyzer.analyze_repository(token, repo_name, nil, MockGitHubClient)

      assert analysis.requested_ref == nil
      assert analysis.resolved_ref_kind == "branch"
      assert analysis.resolved_ref_name == "main"
      assert analysis.resolved_commit_sha == commit_sha
      assert analysis.devcontainer_path == ".devcontainer/devcontainer.json"
      assert analysis.devcontainer_raw == %{"image" => "node:20"}
    end

    test "resolves explicit branch ref" do
      token = "github-token"
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
        {:ok, Jason.encode!(%{"name" => "release-container"})}
      end)

      assert {:ok, analysis} =
               Analyzer.analyze_repository(token, repo_name, "release", MockGitHubClient)

      assert analysis.requested_ref == "release"
      assert analysis.resolved_ref_kind == "branch"
      assert analysis.resolved_ref_name == "release"
      assert analysis.resolved_commit_sha == commit_sha
    end

    test "resolves explicit tag ref" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("c")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_branch, fn ^token, ^repo_name, "v1.2.3" ->
        {:error, :not_found}
      end)
      |> expect(:resolve_tag, fn ^token, ^repo_name, "v1.2.3" ->
        {:ok, %{name: "v1.2.3", commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:error, :not_found}
      end)
      |> expect(:get_file_content, fn ^token, ^repo_name, ".devcontainer.json", ^commit_sha ->
        {:ok, Jason.encode!(%{"features" => %{}})}
      end)

      assert {:ok, analysis} =
               Analyzer.analyze_repository(token, repo_name, "v1.2.3", MockGitHubClient)

      assert analysis.requested_ref == "v1.2.3"
      assert analysis.resolved_ref_kind == "tag"
      assert analysis.resolved_ref_name == "v1.2.3"
      assert analysis.resolved_commit_sha == commit_sha
      assert analysis.devcontainer_path == ".devcontainer.json"
    end

    test "resolves explicit commit sha ref" do
      token = "github-token"
      repo_name = "owner/repo"
      requested_commit_sha = sha("d")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^requested_commit_sha ->
        {:ok, %{commit_sha: requested_commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^requested_commit_sha ->
        {:ok, Jason.encode!(%{"postCreateCommand" => "mix deps.get"})}
      end)

      assert {:ok, analysis} =
               Analyzer.analyze_repository(
                 token,
                 repo_name,
                 requested_commit_sha,
                 MockGitHubClient
               )

      assert analysis.requested_ref == requested_commit_sha
      assert analysis.resolved_ref_kind == "commit"
      assert analysis.resolved_ref_name == nil
      assert analysis.resolved_commit_sha == requested_commit_sha
    end

    test "returns :repo_not_found when repository lookup fails with 404" do
      token = "github-token"
      repo_name = "owner/repo"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:error, :not_found}
      end)

      assert {:error, :repo_not_found} =
               Analyzer.analyze_repository(token, repo_name, nil, MockGitHubClient)
    end

    test "returns :ref_not_found when ref is blank" do
      token = "github-token"
      repo_name = "owner/repo"

      assert {:error, :ref_not_found} =
               Analyzer.analyze_repository(token, repo_name, "", MockGitHubClient)
    end

    test "returns an internal github_error for malformed repository payloads" do
      token = "github-token"
      repo_name = "owner/repo"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{name: repo_name}}
      end)

      assert {:error, {:github_error, 500, %{"message" => "invalid_repository_response"}}} =
               Analyzer.analyze_repository(token, repo_name, nil, MockGitHubClient)
    end

    test "returns :ref_not_found for unknown ref" do
      token = "github-token"
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
               Analyzer.analyze_repository(token, repo_name, "does-not-exist", MockGitHubClient)
    end

    test "returns :no_devcontainer when no devcontainer config is present" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("e")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^commit_sha ->
        {:ok, %{commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:error, :not_found}
      end)
      |> expect(:get_file_content, fn ^token, ^repo_name, ".devcontainer.json", ^commit_sha ->
        {:error, :not_found}
      end)

      assert {:error, :no_devcontainer} =
               Analyzer.analyze_repository(token, repo_name, commit_sha, MockGitHubClient)
    end

    test "returns :invalid_devcontainer_json when devcontainer is not valid JSON" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("f")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^commit_sha ->
        {:ok, %{commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, "{not-json"}
      end)

      assert {:error, :invalid_devcontainer_json} =
               Analyzer.analyze_repository(token, repo_name, commit_sha, MockGitHubClient)
    end

    test "returns :invalid_devcontainer_json when decoded devcontainer is not a map" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("0")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^commit_sha ->
        {:ok, %{commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, Jason.encode!(["node:20"])}
      end)

      assert {:error, :invalid_devcontainer_json} =
               Analyzer.analyze_repository(token, repo_name, commit_sha, MockGitHubClient)
    end

    test "propagates non-not-found devcontainer lookup errors" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("9")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^commit_sha ->
        {:ok, %{commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:error, {:network_error, :timeout}}
      end)

      assert {:error, {:network_error, :timeout}} =
               Analyzer.analyze_repository(token, repo_name, commit_sha, MockGitHubClient)
    end

    test "prefers .devcontainer/devcontainer.json over .devcontainer.json" do
      token = "github-token"
      repo_name = "owner/repo"
      commit_sha = sha("1")

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:ok, %{default_branch: "main"}}
      end)
      |> expect(:resolve_commit, fn ^token, ^repo_name, ^commit_sha ->
        {:ok, %{commit_sha: commit_sha}}
      end)
      |> expect(:get_file_content, fn ^token,
                                      ^repo_name,
                                      ".devcontainer/devcontainer.json",
                                      ^commit_sha ->
        {:ok, Jason.encode!(%{"name" => "preferred"})}
      end)

      assert {:ok, analysis} =
               Analyzer.analyze_repository(token, repo_name, commit_sha, MockGitHubClient)

      assert analysis.devcontainer_path == ".devcontainer/devcontainer.json"
      assert analysis.devcontainer_raw == %{"name" => "preferred"}
    end

    test "returns :unauthorized when GitHub client returns unauthorized" do
      token = "github-token"
      repo_name = "owner/repo"

      MockGitHubClient
      |> expect(:get_repository, fn ^token, ^repo_name ->
        {:error, :unauthorized}
      end)

      assert {:error, :unauthorized} =
               Analyzer.analyze_repository(token, repo_name, nil, MockGitHubClient)
    end
  end

  defp sha(char), do: String.duplicate(char, 40)
end
