defmodule Blank.Components.LocationSelect do
  use Blank.Web, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-target={@myself}>
      <div class="grid grid-cols-2 gap-4">
        <div class="relative col-span-2">
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
              onclick={"setTimeout(() => document.getElementById('#{@id}_input').dispatchEvent(new Event('input', {bubbles: true})), 100)"}
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
        <.fields id={@id} name={@field.name} selected={@selected} readonly={@definition.readonly} />
      </div>
    </div>
    """
  end

  attr :selected, :any
  attr :id, :string
  attr :name, :string
  attr :readonly, :boolean

  defp fields(assigns) do
    assigns = assign(assigns, :multiple?, length(assigns.selected) > 1)

    ~H"""
    <%= for sel <- @selected do %>
      <% {address, lon, lat} = value(sel) %>
      <input type="hidden" name={"#{@name}[type]"} value="Point" />
      <input
        id={"#{@name}_address"}
        type="hidden"
        name={"#{@name}[properties][address]"}
        value={address}
      />
      <.input
        type="text"
        name={"#{@name}[coordinates][]"}
        label="Longitude (DD)"
        onchange={"document.getElementById('#{@name}_address').value = ''; document.getElementById('#{@id}_search_input').value=''; document.getElementById('#{@id}_search_input').dataset.value=''"}
        value={lon}
        readonly={@readonly}
      />
      <.input
        type="text"
        name={"#{@name}[coordinates][]"}
        label="Latitude (DD)"
        onchange={"document.getElementById('#{@name}_address').value = ''; document.getElementById('#{@id}_search_input').value=''; document.getElementById('#{@id}_search_input').dataset.value=''"}
        value={lat}
        readonly={@readonly}
      />
    <% end %>
    """
  end

  defp value_label([%{label: label} | _]), do: label
  defp value_label(_), do: nil

  defp value(%{value: %{coordinates: {lon, lat}, properties: %{"address" => address}}}),
    do: {address, lon, lat}

  defp value(%{value: %{"coordinates" => [lon, lat], "properties" => %{"address" => address}}}),
    do: {address, lon, lat}

  defp value(nil), do: nil

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:selected, [])
     |> assign(:hide_dropdown, false)
     |> assign(:options, [])}
  end

  @impl true
  def update(assigns, socket) do
    if !Map.has_key?(assigns, :search_fun) do
      raise ArgumentError, "a :search_fun is required"
    end

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign(
        :selected,
        List.wrap(value_mapper(assigns.field.value))
      )
    }
  end

  @impl true
  def handle_event("change", params, socket) do
    value = Map.fetch!(params, socket.assigns.field.name <> "_search_input")

    options =
      socket.assigns.search_fun.(value)
      |> Enum.map(&value_mapper/1)

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

  defp value_mapper(%{properties: %{"address" => address}} = item) do
    %{
      label: address,
      value: item
    }
  end

  defp value_mapper(%{"properties" => %{"address" => address}} = item) do
    %{
      label: address,
      value: item
    }
  end

  defp select_option(socket, option) do
    selected = [option]

    assign(socket, :selected, selected)
  end
end
