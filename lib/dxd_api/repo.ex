defmodule DxdApi.Repo do
  use Ecto.Repo,
    otp_app: :dxd_api,
    adapter: Ecto.Adapters.Postgres
end
