defmodule DxdApi.Diary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "diaries" do
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(diary, attrs) do
    diary
    |> cast(attrs, [])
    |> validate_required([])
  end
end
