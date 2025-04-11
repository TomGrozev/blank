defmodule Blank.Field do
  defstruct key: nil,
            filter_key: nil,
            module: Blank.Fields.Text,
            label: nil,
            placeholder: nil,
            viewable: true,
            searchable: false,
            sortable: false,
            readonly: false,
            display_field: nil,
            select: nil,
            children: [],
            path: "/",
            address_fun: nil

  @type t :: %__MODULE__{
          key: atom(),
          filter_key: atom(),
          module: module(),
          label: String.t() | nil,
          placeholder: String.t() | nil,
          viewable: boolean(),
          searchable: boolean(),
          sortable: boolean(),
          readonly: boolean(),
          display_field: atom() | nil,
          select: struct() | nil,
          children: Keyword.t() | nil,
          path: String.t(),
          address_fun: fun() | nil
        }

  @callback validate_field!(opts :: Keyword.t()) :: Keyword.t()
  @callback render_display(assigns :: map()) :: %Phoenix.LiveView.Rendered{}
  @callback render_list(assigns :: map()) :: %Phoenix.LiveView.Rendered{}
  @callback render_form(assigns :: map()) :: %Phoenix.LiveView.Rendered{}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @schema opts[:schema] || []

      @before_compile Blank.Field
      @behaviour Blank.Field

      use Blank.Web, :field

      def __schema__, do: @schema

      @impl Blank.Field
      def validate_field!(opts) do
        Blank.Schema.Validator.validate_field!(@schema, unquote(__MODULE__), opts)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl Phoenix.LiveComponent
      def render(%{type: :list} = assigns) do
        if function_exported?(__MODULE__, :render_list, 1) do
          apply(__MODULE__, :render_list, [assigns])
        else
          render_display(assigns)
        end
      end

      def render(%{type: :display} = assigns) do
        render_display(assigns)
      end

      def render(%{type: :form} = assigns) do
        render_form(assigns)
      end
    end
  end

  @doc false
  @spec new!(atom(), Keyword.t()) :: t()
  def new!(key, field_def) do
    attrs =
      field_def
      |> Keyword.put(:key, key)
      |> Keyword.put_new(:module, Blank.Fields.Text)
      |> Keyword.put_new(:label, Atom.to_string(key) |> Phoenix.Naming.humanize())
      |> Keyword.update(:children, [], fn children ->
        Enum.map(children, fn {k, v} ->
          {k, new!(k, v)}
        end)
      end)

    struct(__MODULE__, attrs)
  end

  @doc false
  def module_for_type(:boolean), do: Blank.Fields.Boolean
  def module_for_type(:utc_datetime), do: Blank.Fields.DateTime
  def module_for_type(_), do: Blank.Fields.Text
end
