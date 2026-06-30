defmodule TestApp.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  schema "test_app_user_tokens" do
    field :token, :binary
    field :context, :string
    belongs_to :user, TestApp.Accounts.User

    timestamps(updated_at: false)
  end

  def by_user_query(user) do
    from t in __MODULE__, where: t.user_id == ^user.id
  end
end
