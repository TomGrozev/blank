defmodule Blank.Components.SearchableSelect do
  use Blank.Web, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-target={@myself}>
      <div class="relative">
        <.input
          type="text"
          id={"#{@id}_search_input"}
          name={"#{@field.name}_search_input"}
          label={@definition.label}
          phx-target={@myself}
          phx-change="change"
          autocomplete="off"
          phx-debounce="300"
          onclick="this.value = ''"
          onfocus="this.value = ''"
          onblur="this.value = this.dataset.value"
          value={value_label(@selected)}
          data-value={value_label(@selected)}
        />
        <input type="hidden" id={"#{@id}_input"} name={@field.name} value={value(@selected)} />
        <input
          :if={@id_field}
          type="hidden"
          id={"#{@id}_id_input"}
          name={@id_field.name}
          value={id_value(@selected)}
        />
        <ul
          :if={not Enum.empty?(@options) and not @hide_dropdown}
          class={[
            "hidden absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md py-1 text-base",
            "shadow-lg ring-1 ring-opacity-5 focus:outline-none sm:text-sm",
            "bg-white dark:bg-gray-700 ring-black dark:ring-white dark:ring-opacity-30"
          ]}
          phx-mounted={
            JS.show(
              to: "##{@id}_options",
              transition:
                {"transition ease-out duration-100", "transform opacity-0 scale-95",
                 "transform opacity-100 scale-100"}
            )
          }
          id={"#{@id}_options"}
          role="listbox"
          phx-click-away={
            JS.push("hide_options", target: @myself)
            |> JS.hide(
              to: "##{@id}_options",
              transition:
                {"transition ease-in duration-75", "transform opacity-100 scale-100",
                 "transform opacity-0 scale-95"}
            )
          }
        >
          <li
            :for={{item, idx} <- Enum.with_index(@options)}
            class={[
              "relative cursor-default select-none py-2 pl-3 pr-9 text-gray-900 dark:text-gray-200",
              "hover:text-white hover:bg-indigo-600 dark:hover:bg-indigo-500"
            ]}
            id={"#{@id}_option-#{idx}"}
            role="option"
            tabindex="-1"
            phx-click="option_selected"
            phx-target={@myself}
            phx-value-option={idx}
            onclick={"setTimeout(() => document.getElementById('#{@id}#{if @id_field, do: "_id", else: ""}_input').dispatchEvent(new Event('input', {bubbles: true})), 100)"}
          >
            <span class={["block truncate", if(item in @selected, do: "font-semibold")]}>
              {item.label}
            </span>

            <span class={[
              "absolute inset-y-0 right-0 flex items-center pr-4",
              if(item in @selected, do: "text-white", else: "text-indigo-600")
            ]}>
              <.icon name="hero-checkmark" class="h-5 w-5" />
            </span>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp value_label([%{label: label} | _]), do: label
  defp value_label(_), do: nil

  defp id_value([%{value: %{"id" => id}} | _]), do: id
  defp id_value([%{value: %{id: id}} | _]), do: id
  defp id_value(_), do: nil

  defp value([%{value: value} | _]), do: encode(value)
  defp value(_), do: nil

  defp encode(%Ecto.Association.NotLoaded{}), do: nil
  defp encode(value) when is_atom(value) or is_binary(value) or is_number(value), do: value
  defp encode(value), do: Phoenix.json_library().encode!(value)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:selected, [])
     |> assign(:hide_dropdown, false)
     |> assign(:id_field, nil)
     |> assign(:options, [])}
  end

  @impl true
  def update(assigns, socket) do
    if !Map.has_key?(assigns, :search_fun) do
      raise ArgumentError, "a :search_fun is required"
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected, selected_option(assigns.field.value, Map.get(assigns, :definition)))}
  end

  defp selected_option(value, field_def) do
    List.wrap(value_mapper(value, field_def))
  end

  @impl true
  def handle_event("change", params, socket) do
    value = Map.fetch!(params, socket.assigns.field.name <> "_search_input")

    options = socket.assigns.search_fun.(value)

    {:noreply,
     socket
     |> assign(:options, options)
     |> assign(:hide_dropdown, false)}
  end

  def handle_event("option_selected", %{"option" => idx}, socket) do
    option = Enum.at(socket.assigns.options, String.to_integer(idx))

    {:noreply,
     socket
     |> select_option(option)
     |> assign(:hide_dropdown, true)}
  end

  def handle_event("hide_options", _, socket) do
    {:noreply, assign(socket, :hide_dropdown, true)}
  end

  defp select_option(socket, option) do
    selected = [option]

    assign(socket, :selected, selected)
  end

  @doc false
  def value_mapper(nil, _definition), do: nil

  def value_mapper(item, nil), do: %{label: item, value: item}

  def value_mapper(item, definition) do
    label =
      Map.get(
        item,
        definition.display_field,
        Map.get(
          item,
          Atom.to_string(definition.display_field)
        )
      )

    %{label: label, value: item}
  end
end
