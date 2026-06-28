defmodule Blank.Fields.Currency do
  @moduledoc """
  Currency field that formats numeric values with a dollar sign.

  In display mode the value is formatted as `$X.XX` (two decimal places,
  defaulting to `$0.00` when nil). The form renders as a number input with a
  banknotes icon prefix.

  ## Example

      fields: [
        price: [module: Blank.Fields.Currency],
        tax: [module: Blank.Fields.Currency, label: "Tax amount"]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <span>
      ${:io_lib.format("~.2f", [@value || 0.0]) |> to_string()}
    </span>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input
        field={@field}
        type="number"
        label={@definition.label}
        disabled={@definition.readonly}
        prefix_icon="hero-banknotes"
      />
    </div>
    """
  end
end
