defmodule FrontmanServer.Repo.Migrations.CreateRepoAnalyses do
  use Ecto.Migration

  def change do
    create table(:repo_analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false, default: "github"
      add :repo_name, :string, null: false
      add :requested_ref, :string
      add :resolved_ref_kind, :string, null: false
      add :resolved_ref_name, :string
      add :resolved_commit_sha, :string, null: false
      add :devcontainer_path, :string, null: false
      add :devcontainer_raw, :map, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:repo_analyses, [:user_id])
    create index(:repo_analyses, [:user_id, :repo_name])
    create index(:repo_analyses, [:resolved_commit_sha])
  end
end
