defmodule DxdApiWeb.DiaryController do
  use DxdApiWeb, :controller
  alias DxdApi.{Repo, Diary}

  def create(conn, _params) do
    case Repo.insert(%Diary{}) do
      {:ok, diary} ->
        conn
        |> put_status(:created)
        |> json(%{id: diary.id})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> text("Failed to create new diary")
    end
  end
end
