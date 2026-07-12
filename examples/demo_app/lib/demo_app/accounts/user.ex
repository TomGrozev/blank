defmodule DemoApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    fields: [
      name: [searchable: true, sortable: true],
      email: [searchable: true],
      status: [sortable: true]
    ],
    identity_field: :name,
    order_field: {:name, :asc}
  }

  schema "demo_app_users" do
    field :name, :string
    field :email, :string
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :status])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end
end
