defmodule Blank.Fields.HasMany do
  @schema [
    children: [
      type: :non_empty_keyword_list,
      keys: [
        *: [
          type: :keyword_list,
          keys: Blank.Schema.Validator.field_schema()
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
  def render_display(%{value: %Ecto.Association.NotLoaded{}} = assigns) do
    ~H"""
    nil
    """
  end

  def render_display(%{value: value, definition: definition} = assigns) do
    display_field = Map.get(definition, :display_field, :id)
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
                disabled={child_def.readonly}
                placeholder={child_def.placeholder}
              />
            </div>
            <button
              type="button"
              class="flex items-center float-right clear-both relative mt-2"
              name={"#{drop_name(@field.name)}[]"}
              value={pf.index}
              phx-click={JS.dispatch("change")}
            >
              <.icon name="hero-x-mark" class="w-6 h-6" /> Delete
            </button>
          </div>
        </.inputs_for>
        <input type="hidden" name={"#{drop_name(@field.name)}[]"} />

        <button
          class="flex items-center mt-14"
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
