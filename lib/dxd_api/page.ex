defmodule DxdApi.Page do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pages" do
    field :hash, :string
    field :plain_hash, :string
    field :file_path, :string
    field :kind, Ecto.Enum, values: [:main, :image]
    field :diary_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:hash, :plain_hash, :file_path, :kind])
    |> validate_required([:hash, :plain_hash, :file_path, :kind])
  end
end
