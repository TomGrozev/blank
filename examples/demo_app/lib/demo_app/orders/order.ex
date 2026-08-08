defmodule DemoApp.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    fields: [
      customer_name: [searchable: true, sortable: true],
      total_amount: [sortable: true],
      status: [sortable: true],
      user: [display_field: :name, searchable: true]
    ],
    identity_field: :customer_name,
    order_field: {:inserted_at, :desc}
  }

  schema "demo_app_orders" do
    field :customer_name, :string
    field :total_amount, :decimal
    field :status, :string, default: "pending"

    belongs_to :user, DemoApp.Accounts.User

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:customer_name, :total_amount, :status, :user_id])
    |> validate_required([:customer_name, :total_amount])
  end
end
