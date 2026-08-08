defmodule DemoApp.Policy do
  @moduledoc """
  Custom authorization policy for the demo app.

  Demonstrates how to implement role-based access control
  using Blank's Policy behaviour.
  """
  use Blank.Authorization.Policy

  # Members can read orders
  def policy(%{roles: roles}, :read, %{resource_type: :order}),
    do: :member in roles or :payment_manager in roles

  # Payment managers can create/update/delete orders
  def policy(%{roles: roles}, action, %{resource_type: :order})
      when action in [:create, :update, :delete],
    do: :payment_manager in roles

  # Members can read users
  def policy(%{roles: roles}, :read, %{resource_type: :user}),
    do: :member in roles

  # Content editors can update users
  def policy(%{roles: roles}, :update, %{resource_type: :user}),
    do: :content_editor in roles
end
