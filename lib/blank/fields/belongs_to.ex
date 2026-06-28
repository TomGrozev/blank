defmodule Blank.Fields.BelongsTo do
  @moduledoc """
  Searchable select field for `belongs_to` associations.

  This field is applied automatically to any `belongs_to` association. In the
  form it renders a `Blank.Components.SearchableSelect` live component that
  lets the Admin search and pick from the related schema's records.

  The `:display_field` option controls which field is shown as the selected
  label. If omitted, the related schema's `identity_field` is used.

  ## Example

      fields: [
        author: [display_field: :full_name, searchable: true]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  use Blank.Field

  alias Blank.Context
  alias Blank.Components.SearchableSelect

  @impl Phoenix.LiveComponent
  def update(%{type: :form} = assigns, socket) do
    %{schema: schema, field: field} = assigns

    %{queryable: queryable, owner_key: owner_key} = schema.__schema__(:association, field.field)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:owner_key, owner_key)
     |> assign(:queryable, queryable)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Blank.Field
  def render_display(%{value: %Ecto.Association.NotLoaded{}} = assigns) do
    ~H"""
    nil
    """
  end

  def render_display(%{value: value, definition: definition} = assigns) do
    display_field =
      Map.get_lazy(definition, :display_field, fn -> Blank.Schema.identity_field(value) end)

    assigns = assign(assigns, :value, Map.get(value || %{}, display_field))

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
      <.live_component
        id={"#{@field.form.name}_#{@field.field}_searchable_select"}
        module={SearchableSelect}
        field={@field}
        id_field={@field.form[@owner_key]}
        definition={@definition}
        search_fun={&search(@repo, @queryable, @definition, &1)}
      />
    </div>
    """
  end

  defp search(repo, schema, definition, query) do
    Context.options_query(repo, schema, definition, query)
    |> Enum.map(&SearchableSelect.value_mapper(&1, definition))
  end
end
