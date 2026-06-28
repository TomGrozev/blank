defmodule Blank.Fields.HasMany do
  @moduledoc """
  Has-many / has-one association field with inline child editing.

  This field is applied automatically to `has_many` and `has_one` associations.
  It renders a list of child items in the form, with buttons to add and remove
  entries. Use the `:children` option to define which sub-fields appear for each
  child.

  ## Schema options

    * `:children` — a keyword list of child field definitions. Each key is a
      field name on the child schema and the value is a keyword list of field
      options (same shape as the top-level `fields:` option in `Blank.Schema`).

  ## Example

      fields: [
        line_items: [
          children: [
            product_name: [label: "Product"],
            quantity: [label: "Qty"]
          ]
        ]
      ]

  See `Blank.Field` for shared options (`:searchable`, `:sortable`, `:viewable`,
  `:readonly`, `:label`, `:placeholder`, etc.).
  """

  @schema [
    children: [
      type: :non_empty_keyword_list,
      keys: [
        *: [
          type: :keyword_list,
          keys: Blank.Field.field_schema()
        ]
      ]
    ]
  ]

  use Blank.Field, schema: @schema

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
  def render_display(%{value: []} = assigns) do
    render_display(%{assigns | value: %Ecto.Association.NotLoaded{}})
  end

  def render_display(%{value: %Ecto.Association.NotLoaded{}} = assigns) do
    ~H"""
    <div class="mt-2 rounded-md border-dashed border-4 border-base-content/40 text-base-content/80 text-center p-4 italic">
      Nothing here yet
    </div>
    """
  end

  def render_display(%{value: value, definition: definition} = assigns) do
    display_field =
      Map.get_lazy(definition, :display_field, fn -> Blank.Schema.identity_field(value) end)

    assigns = assign(assigns, :value, Enum.map_join(value, ", ", &Map.get(&1, display_field)))

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
      <h3 class="font-semibold text-sm">{@definition.label}</h3>
      <div>
        <.inputs_for :let={pf} field={@field}>
          <div class="relative ml-4 space-y-4">
            <div class="flex flex-col space-y-4 w-full sm:space-y-0 sm:space-x-4 sm:flex-row sm:items-start">
              <input type="hidden" name={"#{sort_name(@field.name)}[]"} value={pf.index} />
              <.input
                :for={{child, child_def} <- @definition.children}
                class="w-full"
                type="text"
                field={pf[child]}
                label={child_def.label}
                disabled={@definition.readonly || child_def.readonly}
                placeholder={child_def.placeholder}
              />
            </div>
            <div class="flex justify-end">
              <button
                type="button"
                class="flex items-center relative text-rose-500"
                name={"#{drop_name(@field.name)}[]"}
                value={pf.index}
                phx-click={JS.dispatch("change")}
              >
                <.icon name="hero-x-mark" class="w-6 h-6" /> Delete
              </button>
            </div>
          </div>
        </.inputs_for>
        <input type="hidden" name={"#{drop_name(@field.name)}[]"} />

        <button
          :if={not @definition.readonly}
          class="flex items-center mt-4"
          type="button"
          name={"#{sort_name(@field.name)}[]"}
          value="new"
          phx-click={JS.dispatch("change")}
        >
          <.icon name="hero-plus" class="w-6 h-6 relative" /> Add
        </button>
      </div>
    </div>
    """
  end

  defp sort_name(field) do
    field
    |> String.trim_trailing("]")
    |> Kernel.<>("_sort]")
  end

  defp drop_name(field) do
    field
    |> String.trim_trailing("]")
    |> Kernel.<>("_drop]")
  end
end
