defmodule Blank.Fields.List do
  use Blank.Field

  @impl Blank.Field
  def render_display(assigns) do
    {:array, inner_type} = assigns.schema.__schema__(:type, assigns.definition.key)

    module = Blank.Field.module_for_type(inner_type)

    assigns = assign(assigns, :module, module)

    ~H"""
    <div>
      <div :for={{val, idx} <- Enum.with_index(@value)}>
        <.live_component
          id={"#{@id}_#{idx}"}
          module={@module}
          type={:display}
          definition={@definition}
          schema={@schema}
          value={val}
        />
      </div>
    </div>
    """
  end

  @impl Blank.Field
  def render_form(assigns) do
    ~H"""
    <div>
      <.input field={@field} type="datetime-local" label={@definition.label} />
    </div>
    """
  end
end
