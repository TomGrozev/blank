defmodule Blank.Fields.Text do
  @moduledoc """
  Default field for plain text values.

  This is the fallback field module — any `:string`, `:integer`, `:float`,
  `:decimal`, `:naive_datetime`, or `:date` type that isn't matched by a
  more specific field adapter renders as a simple text input. The label
  defaults to a humanized version of the field name.

  ## Example

      fields: [
        title: [],
        description: [label: "Description", placeholder: "Write something…"]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    ~H"""
    <span>
      {@value}
    </span>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input field={@field} type="text" label={@definition.label} disabled={@definition.readonly} />
    </div>
    """
  end
end
