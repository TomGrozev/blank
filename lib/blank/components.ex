defmodule Blank.Components do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Blank.Gettext

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :wide, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-gray-50/90 dark:bg-gray-700/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class={[
            "w-full p-4 sm:p-6 lg:py-8",
            if(@wide,
              do: "max-w-6xl",
              else: "max-w-3xl"
            )
          ]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-gray-700/10 dark:shadow-gray-500/10 ring-gray-700/10 dark:ring-gray-500/10 relative hidden rounded-2xl bg-white dark:bg-gray-800 p-10 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        Hang in there while we get back on track
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders the Blank logo
  """

  attr :rest, :global

  def logo(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 493.3538873994638 651.77424" {@rest}>
      <path
        d="M51.452 3.257c5.867 2.842 11.173 6.452 16.433 10.285 2.978 2.116 6.063 3.87 9.27 5.613 6.442 4.176 10.038 6.739 14 9 5.075 4.032 7.41 5.477 10 7.25l3.172 2.145 3.828 2.605c35.15 23.97 35.15 23.97 76.844 25.535 15.888-2.256 32.185-2.085 48.21-2.422a974.23 974.23 0 0 0 9.967-.27c20.873-.651 39.127-.217 58.979 7.157 1.49.5 2.98.995 4.473 1.484 28.51 9.63 52.9 27.928 66.527 55.079 2.22 4.514 4.298 9.086 6.324 13.69a456.73 456.73 0 0 1 3.443 7.92c3.07 7.055 6.48 12.724 13.733 15.964 7.652 2.642 15.764 3.65 23.762 4.69 19.762 2.625 33.975 7.129 46.738 23.173 9.827 13.659 14.097 28.21 14.238 44.809l.025 2.803c.014 1.952.024 3.904.032 5.857.012 1.963.032 3.926.062 5.89.193 12.83-.66 24.327-4.357 36.64l-.84 2.823a128.418 128.418 0 0 1-2.348 6.678l-.893 2.368c-5.365 13.78-12.458 25.8-21.92 37.132l-1.8 2.262c-19.827 24.085-49.414 31.986-78.4 38.972l-4.816 1.17a889.74 889.74 0 0 1-9.396 2.224c-11.476 2.722-23.92 5.783-30.587 16.372-5.185 10.123-4.475 26.86-1.742 37.7 7.736 23.982 25.63 43.183 44.457 59.304 15.677 13.694 31.814 28.286 44.285 44.996l1.462 1.918c21.19 27.886 33.33 57.804 39.947 92.045.846 4.35 1.722 8.692 2.59 13.037h-402c-4.464-13.396-8.763-26.63-12.374-40.25l-.698-2.618c-9.71-36.518-17.128-73.5-22.177-110.944l-.458-3.312c-3.02-23.722-3.63-47.566-3.553-71.446.012-3.603.005-7.206-.007-10.81-.057-21.347.34-42.702 4.33-63.745l.634-3.42c8.14-42.51 18.386-90.095 46.304-124.455-1.468-3.833-3.3-5.053-6.875-6.953l-2.988-1.63-3.137-1.667c-8.02-4.272-15.05-8.893-22-14.75a837.1 837.1 0 0 0-3.563-2.75c-13.197-11.588-19.645-30.05-24.973-46.334l-.131-.771c-1.15-6.61-2.05-12.44-1.993-19.464l.153-3.758c.003-2.502-.143-4.85-.126-7.351.017-2.502.02-7.167.014-10.984.005-2.439.012-4.568.021-7.008l.152-4.52c.054-2.653-.19-10.474.756-16.75.36-1.69.4-3.69.733-5.384 10.12-50.057 10.12-50.057 27.19-62.563 6.274-3.092 14.557-2.436 21.064-.261zm-3.734 28.585c-9.788 14.487-3.927 49.579-1.14 65.77 1.743 8.334 4.009 17.472 10.39 23.48 4.316 2.794 7.682 3.49 12.75 2.626 5.467-3.506 8.469-9.615 11.75-15.063 7.303-11.538 17.186-17.031 30.25-20.188l3.003-.636c2.59-.504 2.59-.504 4.434-2.676-.52-5.96-4.01-8.865-8-13l-1.622-1.684C102.55 63.259 95.52 56.334 87.62 50.128c-2.37-1.897-4.564-3.898-6.778-5.973-3.762-3.387-7.76-6.193-12-8.938l-1.815-1.181c-5.714-3.608-13.225-6.406-19.31-2.194zm185.566 132.864c-4.58 5.268-6.13 10.609-6.13 17.449.847 7.26 4.009 12.562 9.626 17.25 5.74 4.047 11.94 5.424 18.875 4.25 7.774-2.174 14.895-6.472 19.438-13.234 2.69-5.74 2.72-11.904 1.062-17.953-2.528-6.383-6.91-11.452-12.938-14.75-11.914-5.123-20.803-1.41-29.933 6.988zm180.809 47.699c-3.808 5.404-3.707 10.256-2.938 16.75 3.11 9.557 9.104 17.836 18.035 22.629 9.652 4.198 15.485 4.873 25.41 1.086 7.103-3.427 13.867-8.984 17.004-16.418 1.91-7.966 1.306-16.046-2.45-23.297-4.872-5.77-9.784-8.585-17.214-9.316a618.171 618.171 0 0 0-9.806-.576c-1.835-.1-3.67-.24-5.502-.381-9.517-.475-16.248 2.246-22.54 9.523zm6.062 70.75c-2.696 3.454-4.827 7.202-7 11-10.538 18.212-27.527 32.268-48 38-6.74 1.617-13.332 2.41-20.25 2.688l-2.77.116c-31.635 1.125-52.675-11.822-75.355-32.554l-2.586-2.422c-2.461-2.207-3.562-2.764-6.851-3.203-4.292.505-5.528 2.05-8.188 5.375-2.464 4.255-2.16 7.28-1 12 6.289 16.205 21.715 25.18 37 32 19.619 7.758 38.097 10.623 59 7 1.384-.212 2.768-.421 4.152-.63 28.018-4.357 55.368-16.555 73.098-39.37a191.35 191.35 0 0 0 2.75-4l1.738-2.55c7.79-11.344 7.79-11.344 10.262-24.45-6.001-2.134-10.567-2.895-16 1z"
        fill="currentColor"
      />
    </svg>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex flex-wrap items-center justify-between gap-6", @class]}>
      <div class="w-full md:w-auto">
        <h1 class="text-2xl/7 font-bold text-gray-900 dark:text-white sm:truncate sm:text-3xl sm:tracking-tight">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-gray-600 dark:text-gray-400">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-1 flex items-center justify-end space-x-4">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  attr :secondary, :boolean, default: false

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-md px-3 py-2 text-sm font-semibold shadow-sm",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
        "disabled:bg-gray-500 disabled:text-white disabled:hover:bg-gray-500",
        button_colour(@secondary),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_colour(true) do
    """
    text-gray-900 dark:text-white
    ring-1 ring-inset ring-gray-300 dark:ring-0
    bg-white dark:bg-white/10 hover:bg-gray-50 dark:hover:bg-white/20 
    """
  end

  defp button_colour(false) do
    """
    text-white 
    bg-indigo-600 dark:bg-indigo-500 hover:bg-indigo-500 dark:hover:bg-indigo-400 
    focus-visible:outline-indigo-600 dark:focus-visible:outline-indigo-500
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-6 border-t border-gray-100 dark:border-white/10">
      <dl class="divide-y divide-gray-100 dark:divide-white/10">
        <div :for={item <- @item} class="px-4 py-6 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
          <dt class="text-sm/6 font-medium text-gray-900 dark:text-white">{item.title}</dt>
          <dd class="mt-1 text-sm/6 text-gray-700 dark:text-gray-400 sm:col-span-2 sm:mt-0">
            {render_slot(item)}
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="min-w-full divide-y divide-gray-300 dark:divide-gray-700">
        <thead>
          <tr>
            <th
              :for={{col, idx} <- Enum.with_index(@col)}
              scope="col"
              class={[
                "py-3.5 text-left text-sm font-semibold text-gray-900 dark:text-white",
                if(idx == 0, do: "pl-4 pr-3 sm:pl-0", else: "px-3")
              ]}
            >
              {col[:label]}
            </th>
            <th :if={@action != []} class="relative py-3.5 pl-3 pr-4 sm:pr-0">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="divide-y divide-gray-200 dark:divide-gray-800"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="group hover:bg-gray-50 dark:hover:bg-gray-800"
          >
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                "relative whitespace-nowrap py-4 text-sm text-gray-500 dark:text-gray-300",
                @row_click && "hover:cursor-pointer"
              ]}
            >
              <div class={["block py-4 px-3", i == 0 && "pl-4 sm:pl-0"]}>
                <span class={[
                  "absolute -inset-y-px -left-4 group-hover:bg-gray-50 dark:group-hover:bg-gray-800 sm:rounded-l-xl",
                  if(@action == [], do: "sm:rounded-r-xl -right-4", else: "right-0")
                ]} />
                <span class={["relative", i == 0 && "font-medium text-gray-900 dark:text-white"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative">
              <div class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-gray-50 dark:group-hover:bg-gray-800 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-indigo-600 dark:text-indigo-400 hover:text-indigo-900 dark:hover:text-indigo-300"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a form filter
  """
  attr :meta, Flop.Meta, required: true
  attr :fields, :list, required: true
  attr :id, :string, default: nil
  attr :on_change, :string, default: "update-filter"
  attr :target, :string, default: nil

  def filter_form(%{meta: meta} = assigns) do
    assigns = assign(assigns, form: Phoenix.Component.to_form(meta), meta: nil)

    ~H"""
    <.form
      class="mt-4 mb-6 flex flex-wrap space-x-4"
      for={@form}
      id={@id}
      phx-target={@target}
      phx-change={@on_change}
      phx-submit={@on_change}
    >
      <Flop.Phoenix.filter_fields :let={i} form={@form} fields={@fields}>
        <.input
          field={i.field}
          label={i.label}
          placeholder={i.label}
          type="search"
          phx-debounce={120}
          {i.rest}
        />
      </Flop.Phoenix.filter_fields>
    </.form>
    """
  end

  @doc ~S"""
  Renders a table with pagination.

  ## Examples

      <.page_table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.page_table>
  """
  attr(:id, :string, required: true)
  attr(:rows, :list, required: true)
  attr(:meta, :map, required: true)
  attr(:path, :any, required: true)
  attr(:filter_fields, :list, default: [])
  attr(:async_result, AsyncResult, default: AsyncResult.ok(:items))
  attr(:plural_name, :string, default: "")
  attr(:rest, :global)
  attr(:row_click, :any, default: nil, doc: "the function for handling phx-click on each row")

  attr(:row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"
  )

  slot :col, required: true do
    attr(:field_def, :map, required: true)
  end

  slot(:action, doc: "the slot for showing user actions in the last table column")

  def page_table(assigns) do
    ~H"""
    <.filter_form
      :if={not (is_nil(@meta) or Enum.empty?(@filter_fields))}
      fields={@filter_fields}
      meta={@meta}
      id={"#{@id}-filter"}
    />
    <.async_result :let={_stream_key} assign={@async_result}>
      <:loading>
        <.loader name={@plural_name} />
      </:loading>
      <:failed :let={_failure}>
        There was an error loading the {Phoenix.Naming.humanize(@plural_name)}. Please try again later.
      </:failed>
      <div class="px-4 sm:px-0">
        <Flop.Phoenix.table
          id={@id}
          items={@rows}
          meta={@meta}
          path={@path}
          row_click={@row_click}
          row_item={@row_item}
          opts={[
            table_attrs: [class: "min-w-full mt-11 sm:w-full"],
            thead_attrs: [class: "text-sm text-left leading-6 text-gray-900 dark:text-white"],
            thead_th_attrs: [class: "p-0 pr-6 pb-4 font-semibold"],
            tbody_attrs: [
              class:
                "relative divide-y divide-gray-300 dark:divide-gray-700 border-t border-gray-300 dark:border-gray-600 text-sm leading-6 text-gray-50"
            ],
            tbody_tr_attrs: [class: "group hover:bg-gray-100 hover:dark:bg-gray-800"],
            tbody_td_attrs: [class: "relative p-0 hover:cursor-pointer"]
          ]}
          {@rest}
        >
          <:col
            :let={row}
            :for={{col, i} <- Enum.with_index(@col)}
            thead_th_attrs={[class: ["p-0 pr-6 pb-4 font-semibold", i > 0 && " hidden sm:table-cell"]]}
            tbody_td_attrs={[
              class: [
                "relative p-0 hover:cursor-pointer",
                if(i > 0, do: "hidden sm:table-cell", else: "w-full sm:w-auto")
              ]
            ]}
            label={col.field_def.label}
            field={col.field_def.filter_key}
          >
            <div class="block py-4 pr-6">
              <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-gray-100 group-hover:dark:bg-gray-800 rounded-l-xl" />
              <span class={["relative text-gray-900 dark:text-gray-300", i == 0 && " font-semibold"]}>
                {render_slot(col, row)}
              </span>
            </div>
          </:col>
          <:action :let={row} col_class="relative w-14 p-0">
            <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
              <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-gray-100 group-hover:dark:bg-gray-800 rounded-r-xl" />
              <span
                :for={action <- @action}
                class="relative ml-4 font-semibold leading-6 text-gray-900 dark:text-gray-100 hover:text-gray-700 hover:dark:text-gray-200"
              >
                {render_slot(action, row)}
              </span>
            </div>
          </:action>
        </Flop.Phoenix.table>
      </div>
      <div class="flex items-center justify-between border-t border-gray-400 px-4 py-3 sm:px-6">
        <Flop.Phoenix.pagination
          meta={@meta}
          path={@path}
          page_links={:none}
          opts={[
            wrapper_attrs: [class: "flex flex-1 justify-between sm:hidden"],
            disabled_class: "!text-gray-400 select-none hover:bg-gray-900",
            next_link_attrs: [
              class:
                "relative inline-flex items-center rounded-md bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-700 leading-6 active:text-white/80"
            ],
            previous_link_attrs: [
              class:
                "relative inline-flex items-center rounded-md bg-gray-900 px-4 py-2 text-sm font-semibold text-white hover:bg-gray-700 leading-6 active:text-white/80"
            ]
          ]}
        />
        <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
          <div>
            <p class="text-sm text-gray-900 dark:text-gray-200">
              Showing
              <select
                name="limit"
                class="mt-1 inline-block rounded-md border border-gray-200 dark:border-gray-700 bg-gray-50/10 dark:bg-gray-800 shadow-sm shadow-gray-200 dark:shadow-gray-900 focus:border-gray-200 focus:dark:border-gray-700 focus:ring-0 sm:text-sm"
              >
                <option
                  :for={val <- [10, 20, 50, 75, 100]}
                  value={val}
                  selected={val == @meta.page_size}
                  phx-click={
                    JS.navigate(
                      Flop.Phoenix.build_path(
                        @path,
                        Map.put(@meta.flop, :page_size, val)
                      )
                    )
                  }
                >
                  {val}
                </option>
              </select>
              of <span class="font-medium">{@meta.total_count}</span>
              results
            </p>
          </div>
          <div>
            <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
            </nav>

            <Flop.Phoenix.pagination
              meta={@meta}
              path={@path}
              opts={[
                wrapper_attrs: [class: "isolate inline-flex -space-x-px rounded-md shadow-sm"],
                current_link_attrs: [
                  class:
                    "relative z-10 inline-flex items-center border border-indigo-600 dark:border-indigo-500 bg-indigo-600 dark:bg-indigo-900/50 px-4 py-2 text-sm font-medium text-white focus:z-20",
                  aria: [current: "page"]
                ],
                disabled_class: "!text-gray-400 select-none hover:bg-gray-700 hover:dark:bg-gray-800",
                next_link_attrs: [
                  class:
                    "order-3 relative inline-flex items-center rounded-r-md border border-gray-300 dark:border-gray-700 hover:bg-gray-100 hover:dark:bg-gray-700 dark:bg-gray-800 px-2 py-2 text-sm font-medium text-gray-900 dark:text-gray-200 focus:z-20"
                ],
                previous_link_attrs: [
                  class:
                    "order-1 relative inline-flex items-center rounded-l-md border border-gray-300 dark:border-gray-700 hover:bg-gray-100 hover:dark:bg-gray-700 dark:bg-gray-800 px-2 py-2 text-sm font-medium text-gray-900 dark:text-gray-200 focus:z-20"
                ],
                next_link_content:
                  {:safe,
                   "<span class=\"sr-only\">Next</span><div class=\"flex items-center justify-center w-5 h-5\">&rsaquo;</div>"},
                previous_link_content:
                  {:safe,
                   "<span class=\"sr-only\">Previous</span><div class=\"flex items-center justify-center w-5 h-5\">&lsaquo;</div>"},
                pagination_list_attrs: [class: "order-2 flex"],
                ellipsis_attrs: [
                  class:
                    "relative inline-flex items-center border border-gray-300 dark:border-gray-700 hover:bg-gray-100 hover:dark:bg-gray-700 dark:bg-gray-800 px-4 py-2 text-sm font-medium text-gray-900 dark:text-gray-200 focus:z-20"
                ],
                pagination_link_attrs: [
                  class:
                    "relative inline-flex items-center border border-gray-300 dark:border-gray-700 hover:bg-gray-100 hover:dark:bg-gray-700 dark:bg-gray-800 px-4 py-2 text-sm font-medium text-gray-900 dark:text-gray-200 focus:z-20"
                ]
              ]}
            />
          </div>
        </div>
      </div>
    </.async_result>
    """
  end

  @doc """
  Loading spinner
  """
  attr :name, :string, required: true

  def loader(assigns) do
    ~H"""
    <div class="flex items-center justify-center w-full h-full min-h-96">
      <div class="flex flex-col items-center">
        <.icon name="hero-arrow-path" class="h-10 w-10 animate-spin" />
        <span class="text-sm italic">Loading {Phoenix.Naming.humanize(@name)}...</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :disabled, :boolean, default: false

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label class="flex items-center gap-4 text-sm leading-6 text-gray-600
        dark:text-gray-400">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-gray-300 dark:border-white/10 text-gray-900 dark:text-indigo-600 dark:bg-white/5 focus:ring-0"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-md border-0 py-1.5 shadow-sm ring-1 ring-inset sm:text-sm sm:leading-6",
          "dark:bg-white/5 focus:ring-2 focus:ring-inset",
          @disabled &&
            "disabled:cursor-not-allowed disabled:bg-gray-50 dark:disabled:bg-white/10 disabled:text-gray-500 dark:disabled:text-gray-100 disabled:ring-gray-200 dark:disabled:ring-white/5",
          @errors == [] &&
            "text-gray-900 dark:text-white ring-gray-300 dark:ring-white/10 focus:ring-indigo-600 dark:focus:ring-indigo-500 placeholder:text-gray-400",
          @errors != [] && "text-red-900 ring-red-300 placeholder:text-red-300 focus:ring-red-500"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-gray-900 focus:ring-0 sm:text-sm sm:leading-6 min-h-[6rem]",
          @errors == [] && "border-gray-300 focus:border-gray-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "search"} = assigns) do
    ~H"""
    <div class="relative flex-1 min-w-64 mt-2">
      <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
        <.icon name="hero-magnifying-glass" class="w-5 h-5 text-gray-500 dark:text-gray-400" />
      </div>
      <input
        type="text"
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "block w-full rounded-md border-0 py-1.5 shadow-sm ring-1 ring-inset sm:text-sm sm:leading-6 pl-10",
          "dark:bg-white/5 focus:ring-2 focus:ring-inset",
          @disabled &&
            "disabled:cursor-not-allowed disabled:bg-gray-50 dark:disabled:bg-white/10 disabled:text-gray-500 dark:disabled:text-gray-100 disabled:ring-gray-200 dark:disabled:ring-white/5",
          @errors == [] &&
            "text-gray-900 dark:text-white ring-gray-300 dark:ring-white/10 focus:ring-indigo-600 dark:focus:ring-indigo-500 placeholder:text-gray-400",
          @errors != [] && "text-red-900 ring-red-300 placeholder:text-red-300 focus:ring-red-500"
        ]}
        disabled={@disabled}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="w-full">
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-md border-0 py-1.5 shadow-sm ring-1 ring-inset sm:text-sm sm:leading-6",
          "dark:bg-white/5 focus:ring-2 focus:ring-inset",
          @disabled &&
            "disabled:cursor-not-allowed disabled:bg-gray-50 dark:disabled:bg-white/10 disabled:text-gray-500 dark:disabled:text-gray-100 disabled:ring-gray-200 dark:disabled:ring-white/5",
          @errors == [] &&
            "text-gray-900 dark:text-white ring-gray-300 dark:ring-white/10 focus:ring-indigo-600 dark:focus:ring-indigo-500 placeholder:text-gray-400",
          @errors != [] && "text-red-900 ring-red-300 placeholder:text-red-300 focus:ring-red-500"
        ]}
        disabled={@disabled}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-2 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders the list display of a field
  """
  attr :definition, :list, required: true, doc: "the field definition"
  attr :value, :any, required: true, doc: "the value of the field"
  attr :id, :any, required: true, doc: "the id value"
  attr :schema, :atom, doc: "the schema to use"
  attr :time_zone, :string, doc: "the timezone to use for datetime"

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

  def field_form(assigns) do
    ~H"""
    <.live_component
      id={"field_#{@definition.key}_form"}
      module={@definition.module}
      type={:form}
      {Map.take(assigns, [:definition, :field, :schema, :repo, :time_zone])}
    />
    """
  end

  @doc """
  Renders a stat
  """

  attr :stat, :map, required: true
  attr :module, :atom, required: true

  def stat_component(%{stat: stat, module: module}) do
    %{name: name, value: value, display: display_module, formatter: formatter} =
      stat

    value =
      if value.ok? do
        Map.update!(value, :result, &format_val(&1, module, formatter))
      else
        value
      end

    Phoenix.LiveView.TagEngine.component(
      Function.capture(display_module, :render, 1),
      [value: value, name: name],
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  defp format_val(value, _module, nil), do: value

  defp format_val(value, module, formatter) when is_function(formatter, 2),
    do: formatter.(module, value)

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(Blank.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(Blank.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
