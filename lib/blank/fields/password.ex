defmodule Blank.Fields.Password do
  @moduledoc """
  Password field with masked display.

  In list and display views the value is replaced with asterisks (`************`)
  so the actual hash is never shown. The form renders as a `password` input.
  The underlying Ecto type is `:string` — use the `:hashed_password` field
  from `Blank.Accounts.User` as a reference for how hashed values are stored.

  ## Example

      fields: [
        password: [module: Blank.Fields.Password],
        current_password: [module: Blank.Fields.Password, viewable: false]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <span>************</span>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input
        field={@field}
        type="password"
        label={@definition.label}
        disabled={@definition.readonly}
      />
    </div>
    """
  end
end
