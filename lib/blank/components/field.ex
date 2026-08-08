defmodule Blank.Components.Field do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Renders the list display of a field
  """
  attr :definition, :list, required: true, doc: "the field definition"
  attr :value, :any, required: true, doc: "the value of the field"
  attr :id, :any, required: true, doc: "the id value"
  attr :schema, :atom, doc: "the schema to use"
  attr :time_zone, :string, doc: "the timezone to use for datetime"
  attr :path_prefix, :string, doc: "the admin panel path prefix"

  @spec field_list(map()) :: Phoenix.LiveView.Rendered.t()
  def field_list(assigns) do
    ~H"""
    <.live_component
      id={"field_#{@definition.key}_#{@id}"}
      module={@definition.module}
      type={:list}
      definition={@definition}
      schema={@schema}
      value={@value}
      time_zone={@time_zone}
      path_prefix={@path_prefix}
    />
    """
  end

  @doc """
  Renders the display of a field
  """
  attr :definition, :list, required: true, doc: "the field definition"
  attr :value, :any, required: true, doc: "the value of the field"
  attr :id, :any, required: true, doc: "the id value"
  attr :schema, :atom, doc: "the schema to use"
  attr :time_zone, :string, doc: "the timezone to use for datetime"
  attr :path_prefix, :string, doc: "the admin panel path prefix"

  @spec field_display(map()) :: Phoenix.LiveView.Rendered.t()
  def field_display(assigns) do
    ~H"""
    <.live_component
      id={"field_#{@definition.key}_#{@id}"}
      module={@definition.module}
      type={:display}
      definition={@definition}
      schema={@schema}
      value={@value}
      time_zone={@time_zone}
      path_prefix={@path_prefix}
    />
    """
  end

  @doc """
  Renders a form version of the field
  """
  attr :definition, :list, required: true, doc: "the field definition"

  attr :field, Phoenix.HTML.FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :repo, :atom, doc: "the repo used for querying"
  attr :schema, :atom, doc: "the schema to use"
  attr :time_zone, :string, doc: "the timezone to use for datetime"
  attr :path_prefix, :string, doc: "the admin panel path prefix"

  @spec field_form(map()) :: Phoenix.LiveView.Rendered.t()
  def field_form(assigns) do
    ~H"""
    <.live_component
      id={"field_#{@definition.key}_form"}
      module={@definition.module}
      type={:form}
      {Map.take(assigns, [:definition, :field, :schema, :repo, :time_zone, :path_prefix])}
    />
    """
  end
end
