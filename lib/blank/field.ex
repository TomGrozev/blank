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

  The built-in fields are:

    * Blank.Fields.BelongsTo - for a belongs to definition it will show a
      searchable select to select the element
    * Blank.Fields.Boolean - a simple checkbox
    * Blank.Fields.DateTime - a datetime picker
    * Blank.Fields.HasMany - a has many that has the ability to add and remove
      items
    * Blank.Fields.Location - a geo location field input (with ability for
      searching)
    * Blank.Fields.List - a list of other fields
    * Blank.Fields.Password - a password input
    * Blank.Fields.QRCode - a text field that is turned into a qr code
    * Blank.Fields.Text - a simple text input (the default for all regular fields)

  Blank will do its best to automatically choose the right field module but you
  can override it by setting the `:module` option in the field definition.
  This includes for associations, such as BelongsTo and HasMany, which will be set
  automatically for fields that are those associations.

  You can also define your own field by implementing this module.

  ### Example custom field

  Below is an example of how you could implement your own QRCode field. This is
  losely based on how Blank implements the QRCode field.

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

          qr_path =
            socket.router.__blank_prefix__()
            |> URI.parse()
            |> URI.append_path("/qrcode")
            |> URI.append_query(URI.encode_query(%{code: value, path: path}))
            |> URI.to_string()

          download_path =
            Phoenix.VerifiedRoutes.unverified_path(socket, socket.router, qr_path)

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
            <div class="inline-flex flex-col items-center justify-center space-y-4 p-4 bg-gray-100 dark:bg-gray-800 shadow rounded-xl">
              <div class="rounded-lg overflow-hidden inline-block bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
                {raw(@qr_code)}
              </div>
              <span class="text-gray-900 dark:text-white font-bold text-xl">{@value}</span>
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
  #{NimbleOptions.docs(Blank.Schema.Validator.field_schema())}

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

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @schema opts[:schema] || []

      @before_compile Blank.Field
      @behaviour Blank.Field

      use Blank.Web, :field

      def __schema__, do: @schema

      @doc false
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
