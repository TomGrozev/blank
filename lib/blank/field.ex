defmodule Blank.Field do
  @moduledoc """
  Field definition for rendering fields

  A field is actually a Phoenix LiveComponent and has its own state cycle.
  Therefore, you can use the `Phoenix.LiveComponent` functions such as
  `c:Phoenix.LiveComponent.update/2`.

  > #### Note {: .info}
  >
  > You don't need to implement the `c:Phoenix.LiveComponent.render/1` function as
  > that is already implemented and will call the required render function based
  > on where it is used.

  ## Using fields

  The built-in field adapters live under `Blank.Fields`. They are:

    * `BelongsTo` - for a belongs to definition it will show a
      searchable select to select the element
    * `Boolean` - a simple checkbox
    * `DateTime` - a datetime picker
    * `HasMany` - a has many that has the ability to add and remove
      items
    * `Location` - a geo location field input (with ability for
      searching)
    * `List` - a list of other fields
    * `Password` - a password input
    * `QRCode` - a text field that is turned into a qr code
    * `Text` - a simple text input (the default for all regular fields)

  Blank will do its best to automatically choose the right field module but you
  can override it by setting the `:module` option in the field definition.
  This includes for associations, such as BelongsTo and HasMany, which will be set
  automatically for fields that are those associations.

  You can also define your own field by implementing this module.

  ### Example custom field

  Below is an example of how you could implement your own QRCode field. This is
  loosely based on how Blank implements the QRCode field.

      defmodule MyApp.Fields.QRCode do
        @schema [
          path: [
            type: :string,
            doc: "The path from the base url for the code to be applied to"
          ]
        ]

        use Blank.Field, schema: @schema

        @impl Phoenix.LiveComponent
        def update(%{value: value} = assigns, socket) do
          path = Map.get(assigns.definition, :path, "/")
          path_prefix = Map.get(assigns, :path_prefix, "/")

          download_path =
            path_prefix
            |> URI.parse()
            |> URI.append_path("/qrcode")
            |> URI.append_query(URI.encode_query(%{code: value, path: path}))
            |> URI.to_string()

          {:ok,
          socket
          |> assign(assigns)
          |> assign(:qr_code, Blank.Utils.QRCode.svg(value, path))
          |> assign(:download_path, download_path)}
        end

        def update(assigns, socket) do
          {:ok, assign(socket, assigns)}
        end

        @impl Blank.Field
        def render_list(assigns) do
          ~H\"""
          <div>
            <span>{@value}</span>
          </div>
          \"\"\"
        end

        @impl Blank.Field
        def render_display(assigns) do
          ~H\"""
          <div class="mt-4">
            <div class="inline-flex flex-col items-center justify-center space-y-4 p-4 bg-base-100 shadow rounded-xl">
              <div class="rounded-lg overflow-hidden inline-block bg-base-200">
                {raw(@qr_code)}
              </div>
              <span class="font-bold text-xl">{@value}</span>
              <.link href={@download_path} target="_blank">
                <.button>
                  <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> Download
                </.button>
              </.link>
            </div>
          </div>
          \"\"\"
        end

        @impl Blank.Field
        def render_form(assigns) do
          ~H\"""
          <div>
            <.input field={@field} type="text" label={@definition.label} disabled={@definition.readonly} />
          </div>
          \"\"\"
        end
      end

  ## Schema

  The default field schema is:
  #{NimbleOptions.docs(Blank.Field.Options.__schema__())}

  A field's definition is validated using the field schema merged with
  the default field schema.

  ### Custom schema

  You can add custom schema options in addition to the default schema by
  supplying it to the `use Blank.Field` definition. For example the QR Code
  field uses the following schema:

      @schema [
        path: [
          type: :string,
          doc: "The path from the base url for the code to be applied to"
        ]
      ]

      use Blank.Field, schema: @schema

  """

  defstruct key: nil,
            filter_key: nil,
            module: nil,
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
          module: module() | nil,
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

  @doc """
  Renderer for the detail showing of the field

  This is used on the show/detail page of an object.
  """
  @callback render_display(assigns :: map()) :: %Phoenix.LiveView.Rendered{}

  @doc """
  Renderer for the listing display of the field

  This is used on the list table view of the object.

  If not defined, `render_display/1` will be used.
  """
  @callback render_list(assigns :: map()) :: %Phoenix.LiveView.Rendered{}

  @doc """
  Renderer for the form showing of the field

  This is used on the edit page for an object.
  """
  @callback render_form(assigns :: map()) :: %Phoenix.LiveView.Rendered{}

  @optional_callbacks render_list: 1

  alias Blank.Errors.InvalidConfigError
  alias Blank.Field.Options

  @doc false
  @spec field_schema() :: keyword()
  def field_schema, do: Options.__schema__()

  @doc false
  @spec validate_field!(keyword(), module(), keyword()) :: keyword()
  def validate_field!(schema, caller, opts) do
    field_schema = Keyword.merge(Options.__schema__(), schema)

    case NimbleOptions.validate(opts, field_schema) do
      {:ok, opts} ->
        opts

      {:error, err} ->
        raise InvalidConfigError.from_nimble(err,
                caller: caller,
                module: Blank.Schema,
                usage: "@derive"
              )
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @schema opts[:schema] || []

      @before_compile Blank.Field
      @behaviour Blank.Field

      use Blank.Web, :field

      def __schema__, do: @schema

      @doc false
      def validate_field!(opts) do
        Blank.Field.validate_field!(@schema, unquote(__MODULE__), opts)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl true
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
end
