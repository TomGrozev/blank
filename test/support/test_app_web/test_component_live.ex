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

  @items [
    %{label: "Apple", value: "apple"},
    %{label: "Banana", value: "banana"},
    %{label: "Cherry", value: "cherry"}
  ]

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
     |> assign(:search_fun, &search_items/1)}
  end

  defp search_items(term) when term in [nil, ""], do: @items

  defp search_items(term) do
    downcased_term = String.downcase(term)

    Enum.filter(@items, fn item ->
      String.contains?(String.downcase(item.label), downcased_term)
    end)
  end
end
