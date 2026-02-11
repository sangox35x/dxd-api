defmodule DxdApiWeb.DiaryController do
  use DxdApiWeb, :controller
  alias DxdApi.{Repo, Diary, Page}
  import Ecto.Query, only: [from: 2]

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

  defp make_metadata(diary_id) do
    %{
      pages:
        Page
        |> Repo.all_by(diary_id: diary_id, kind: :main)
        |> Enum.map(fn page ->
          %{
            createdAt: page.inserted_at,
            hash: page.hash,
            id: page.id,
            plainHash: page.plain_hash,
            images:
              Page
              |> Repo.all_by(diary_id: diary_id, kind: :main)
              |> Enum.map(fn image ->
                %{hash: image.hash, id: image.id, plainHash: image.plain_hash}
              end)
          }
        end)
    }
  end

  def archive(conn, params) do
    diary_id = params["id"]
    archive_dir = "data/download"
    archive_path = Path.join([archive_dir, "#{diary_id}.zip"])
    tmp_dir = "/tmp/diary_#{diary_id}"

    File.mkdir_p!(archive_dir)
    File.mkdir_p!(tmp_dir)

    metadata_bin =
      diary_id
      |> make_metadata()
      |> Jason.encode!()

    metadata_path = "metadata.json"

    File.write!(
      Path.join([tmp_dir, metadata_path]),
      metadata_bin,
      [:write]
    )

    all_pages =
      Page
      |> Repo.all_by(diary_id: diary_id)
      |> Enum.map(&%{store_path: &1.file_path, path: &1.hash})

    Enum.each(all_pages, &File.cp!(&1.store_path, Path.join([tmp_dir, &1.path])))

    all_path =
      [metadata_path | Enum.map(all_pages, & &1.path)]

    :zip.create(
      String.to_charlist(archive_path),
      Enum.map(all_path, &String.to_charlist/1),
      cwd: String.to_charlist(tmp_dir)
    )

    conn
    |> put_status(:ok)
    |> send_download({:file, archive_path})
  end

  def read(conn, params) do
    metadata = make_metadata(params["id"])

    files =
      Page
      |> Repo.all_by(diary_id: params["id"])
      |> Stream.map(&Map.from_struct/1)
      |> Stream.map(&%{hash: &1.hash, file_path: &1.file_path})

    boundary = "--#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"

    {:ok, conn} =
      conn
      |> put_resp_header("content-type", "multipart/mixed;boundary=#{boundary}")
      |> send_chunked(200)
      |> chunk("""
      --#{boundary}
      Content-Type: "application/json"
      Content-Disposition: attachment; name="metadata"

      #{Jason.encode!(metadata)}
      """)

    {:ok, conn} =
      files
      |> Enum.reduce({:ok, conn}, fn file, {:ok, conn} ->
        conn
        |> chunk("""
        --#{boundary}
        Content-Type: application/octed-stream
        Content-Disposition: attachment; name=#{file.hash}

        #{File.read!(file.file_path)}
        """)
      end)

    {:ok, conn} =
      conn
      |> chunk("""
      --#{boundary}--
      """)

    conn
  end

  def update(conn, params) do
    with {:ok, plane_metadata} <- Map.fetch(params, "metadata"),
         {:ok, metadata} <- Jason.decode(plane_metadata),
         :ok <- validate_metadata_page_id(params, metadata),
         {:ok, hashes} <- enum_hash(metadata),
         :ok <- validate_files(params, hashes),
         :ok <- validate_hash(params, metadata) do
      %{"pages" => pages, "newPage" => new_page} = metadata
      update_old_pages(params, pages)
      insert_new_pages(params, new_page)

      conn
      |> put_status(:created)
      |> text("Succsess to update")
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> text("Error")

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> text(message)
    end
  end

  defp validate_metadata_page_id(%{"id" => diary_id}, %{"pages" => pages}) do
    meta_id_set =
      pages
      |> Enum.map(&Map.get(&1, "id"))
      |> MapSet.new()

    repo_id_set =
      from(page in Page, where: page.diary_id == ^diary_id)
      |> Repo.all()
      |> Enum.map(& &1.id)
      |> MapSet.new()

    if MapSet.equal?(meta_id_set, repo_id_set) do
      :ok
    else
      {:error, "Invalid `pages` field"}
    end
  end

  defp sha256(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end

  defp enum_hash(%{"pages" => pages, "newPage" => new_page}) do
    hashes =
      [
        pages
        |> Enum.map(&Map.get(&1, "hash")),
        [new_page |> Map.get("hash")],
        new_page
        |> Map.get("images", [])
        |> Enum.map(&Map.get(&1, "hash"))
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(& &1)

    {:ok, hashes}
  end

  # TODO)) Impl validation
  defp validate_files(_, _) do
    :ok
  end

  # TODO)) Impl validation
  defp validate_hash(_, _) do
    :ok
  end

  defp update_old_page(params, %{"hash" => hash, "id" => page_id}) do
    IO.puts("[DEBUG] Start `update_old_page`")
    File.cp!(params[hash].path, Path.join(["data/pages", hash]))

    Repo.one(from page in Page, where: page.id == ^page_id)
    |> Ecto.Changeset.change(hash: hash)
    |> Repo.update()
  end

  defp update_old_pages(params, pages) do
    pages
    |> Enum.each(&update_old_page(params, &1))
  end

  defp insert_new_pages(%{"id" => diary_id} = params, %{
         "hash" => main_hash,
         "images" => main_images,
         "plainHash" => main_plain_hash
       }) do
    IO.puts("[DEBUG] Start `insert_new_pages`")

    main = %{
      hash: main_hash,
      plain_hash: main_plain_hash
    }

    images =
      main_images
      |> Enum.map(fn %{"hash" => hash, "plainHash" => plain_hash} ->
        %{hash: hash, plain_hash: plain_hash}
      end)

    pages =
      [main | images]
      |> Enum.map(&Map.put_new(&1, :file_path, Path.join(["data/pages", &1.hash])))

    pages
    |> Enum.each(fn %{hash: hash, file_path: path} -> File.cp!(params[hash].path, path) end)

    [main | images] =
      pages
      |> Enum.map(&Map.put_new(&1, :diary_id, diary_id))

    main =
      Repo.insert(%Page{
        diary_id: main.diary_id,
        hash: main.hash,
        plain_hash: main.plain_hash,
        file_path: main.file_path,
        kind: :main
      })

    images =
      images
      |> Enum.map(
        &(&1
          |> Map.put_new(:kind, :image)
          |> Map.put_new(:inserted_at, main.inserted_at)
          |> Map.put_new(:updated_at, main.updated_at))
      )

    Repo.insert_all(Page, images)
  end
end
