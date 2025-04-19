defmodule Blank.Fields.List do
  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    {:array, inner_type} = assigns.schema.__schema__(:type, assigns.definition.key)

    module = Blank.Field.module_for_type(inner_type)

    assigns = assign(assigns, :module, module)

    ~H"""
    <div>
      <ol :if={@value}>
        <li :for={{val, idx} <- Enum.with_index(@value)}>
          <.live_component
            id={"#{@id}_#{idx}"}
            module={@module}
            type={:display}
            definition={@definition}
            schema={@schema}
            time_zone={@time_zone}
            value={val}
          />
        </li>
      </ol>
    </div>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    {:array, inner_type} = assigns.schema.__schema__(:type, assigns.definition.key)

    module = Blank.Field.module_for_type(inner_type)

    assigns =
      assign(assigns,
        module: module,
        label: assigns.definition.label,
        definition: Map.merge(assigns.definition, %{module: module, label: nil})
      )

    ~H"""
    <div>
      <div :if={@field.value}>
        <h4 class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">{@label}</h4>
        <ol class="ml-4 space-y-6">
          <li :for={{val, idx} <- Enum.with_index(@field.value)} class="space-y-2">
            <.live_component
              id={"#{@id}_#{idx}"}
              module={@module}
              type={:form}
              definition={@definition}
              schema={@schema}
              time_zone={@time_zone}
              field={new_field(@field, val, idx)}
            />
            <div :if={!@definition.readonly} class="flex justify-end">
              <button
                type="button"
                class="flex items-center relative text-rose-500"
                phx-click="remove-from-list"
                phx-value-index={idx}
                phx-target={@myself}
              >
                <.icon name="hero-x-mark" class="w-6 h-6" /> Delete
              </button>
            </div>
          </li>
        </ol>
        <button
          :if={!@definition.readonly}
          class="flex items-center mt-2"
          type="button"
          phx-click="add-to-list"
          phx-target={@myself}
        >
          <.icon name="hero-plus" class="w-6 h-6 relative" /> Add
        </button>
      </div>
    </div>
    """
  end

  defp new_field(field, val, idx) do
    Map.merge(field, %{
      id: "#{field.id}_#{idx}",
      name: "#{field.name}[]",
      value: val
    })
  end

  @impl Phoenix.LiveComponent
  def handle_event("add-to-list", _params, socket) do
    {:noreply, assign(socket, :field, Map.update!(socket.assigns.field, :value, &(&1 ++ [nil])))}
  end

  @impl Phoenix.LiveComponent
  def handle_event("remove-from-list", %{"index" => idx}, socket) do
    {:noreply,
     assign(
       socket,
       :field,
       Map.update!(socket.assigns.field, :value, &List.delete_at(&1, String.to_integer(idx)))
     )}
  end
end
