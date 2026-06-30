defmodule TestAppWeb.TestComponentLive do
  @moduledoc false
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="test-component-wrapper">
      <.live_component module={@component_module} id={@component_id} {@component_assigns} />
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end

defmodule TestAppWeb.TestSearchableSelectLive do
  @moduledoc false
  use Phoenix.LiveView

  alias Blank.Components.SearchableSelect

  def render(assigns) do
    ~H"""
    <div id="test-select-wrapper">
      <form id="test-form">
        <.live_component
          module={SearchableSelect}
          id="test-searchable-select"
          field={@field}
          definition={@definition}
          search_fun={@search_fun}
        />
      </form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    search_fun = fn term ->
      items = [
        %{label: "Apple", value: "apple"},
        %{label: "Banana", value: "banana"},
        %{label: "Cherry", value: "cherry"}
      ]

      if term == "" or is_nil(term) do
        items
      else
        Enum.filter(items, fn item ->
          String.contains?(String.downcase(item.label), String.downcase(term))
        end)
      end
    end

    field = %Phoenix.HTML.FormField{
      id: "test-field",
      name: "test[field]",
      value: nil,
      field: :field,
      form: %Phoenix.HTML.Form{},
      errors: []
    }

    definition = %{label: "Test Select"}

    {:ok,
     socket
     |> assign(:field, field)
     |> assign(:definition, definition)
     |> assign(:search_fun, search_fun)}
  end
end
