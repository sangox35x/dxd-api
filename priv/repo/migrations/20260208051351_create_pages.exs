defmodule DxdApi.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    create table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :hash, :string
      add :plain_hash, :string
      add :file_path, :string
      add :kind, :string
      add :diary_id, references(:diaries, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:pages, [:diary_id])
  end
end
