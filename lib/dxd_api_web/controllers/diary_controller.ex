defmodule DxdApiWeb.DiaryController do
  use DxdApiWeb, :controller
  alias DxdApi.{Repo, Diary}

  def create(conn, _params) do
    case Repo.insert(%Diary{}) do
      {:ok, diary} ->
        conn
        |> put_status(:created)
        |> json(%{id: diary.id})
    end
  end
end
