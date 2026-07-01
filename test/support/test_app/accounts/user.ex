defmodule TestApp.Accounts.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    identity_field: :email,
    fields: [
      email: [searchable: true]
    ]
  }

  schema "test_app_users" do
    field :email, :string
    field :name, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
