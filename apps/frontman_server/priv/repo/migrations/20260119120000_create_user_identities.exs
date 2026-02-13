defmodule FrontmanServer.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  def change do
    create table(:user_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_id, :string, null: false
      add :provider_email, :string
      add :provider_name, :string
      add :provider_avatar_url, :string
      add :last_signed_in_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_identities, [:user_id, :provider])
    create unique_index(:user_identities, [:provider, :provider_id])
  end
end
