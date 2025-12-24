defmodule Blank.Components.ImportComponent do
  @moduledoc false
  use Blank.Web, :live_component

  alias Blank.Context

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Bulk Import {@plural_name}
        <:subtitle>
          Use this form to import {@plural_name} in bulk by uploading a CSV with
          your data.
        </:subtitle>
      </.header>

      <.simple_form
        :if={@sample_rows == []}
        for={to_form(%{})}
        id="csv-upload-form"
        phx-target={@myself}
        phx-change="validate_upload"
        phx-submit="parse"
      >
        <label
          :if={@sample_rows == []}
          for={@uploads.csv_file.ref}
          phx-drop-target={@uploads.csv_file.ref}
          class={[
            "relative cursor-pointer block w-full rounded-lg border-2 border-gray-300 p-12 text-center flex items-center justify-center focus:outline-none",
            if(@uploads.csv_file.entries == [], do: "border-dashed hover:border-gray-400", else: "")
          ]}
        >
          <div class={@uploads.csv_file.entries != [] && "hidden"}>
            <.icon name="hero-arrow-up-tray" class="mx-auto h-12 w-12 text-base-content/40" />
            <p class="mb-2 text-sm">
              <span class="font-semibold">Click to upload</span> or drag and drop
            </p>
            <p class="text-xs">
              CSV
            </p>
          </div>

          <div :for={entry <- @uploads.csv_file.entries} class="flex items-center space-x-4">
            <.icon name="hero-document-chart-bar" class="w-24 h-24" />
            <div>
              <p>{entry.client_name}</p>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-target={@myself}
                phx-value-ref={entry.ref}
                aria-label="cancel"
                class="flex items-center text-rose-500"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" /> Remove
              </button>
            </div>
          </div>
          <.live_file_input upload={@uploads.csv_file} class="hidden" />
        </label>

        <div :for={err <- upload_errors(@uploads.csv_file)} class="rounded-md bg-rose-50 p-4 my-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-exclamation-triangle" class="h-5 w-5
        text-rose-400" />
            </div>
            <div class="ml-3">
              <div class="mt-2 text-sm text-rose-700">
                <p>
                  {error_to_string(err)}
                </p>
              </div>
            </div>
          </div>
        </div>

        <:actions>
          <.button
            class="btn btn-primary ml-auto"
            disabled={@uploads.csv_file.entries == []}
            phx-disable-with="Saving..."
          >
            Parse CSV
          </.button>
        </:actions>
      </.simple_form>

      <.simple_form
        :if={@sample_rows != []}
        for={@form}
        id="csv-import-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="import"
      >
        <h2 class="text-xl font-bold mb-4">Map the fields</h2>
        <p class="mb-8">Below is a sample of the data in your spreadsheet file. Please map
          the fields in the spreadsheet to the fields in the {@name} model.</p>

        <div class="my-10">
          <table>
            <tr class="text-base-content/40">
              <td class="px-2">Model field</td>
              <td class="px-2"></td>
              <td class="px-2">CSV field</td>
              <td class="px-2">Splitter regex</td>
              <td class="px-2">Value splitter regex</td>
              <td class="px-2">Field order</td>
            </tr>
            <tr :for={{field, def} <- @fields}>
              <td class="px-2">
                <span class="mt-2">{def.label}</span>
              </td>
              <td class="px-2">
                <.icon name="hero-arrow-long-right" class="w-8 h-8 mt-2 mx-8" />
              </td>
              <td class="px-2">
                <.input type="select" field={@form[field]} prompt="---" options={@csv_headings} />
              </td>
              <td class="px-2">
                <.input type="text" placeholder="None" field={@form[splitter_key(field)]} />
              </td>
              <td class="px-2">
                <.input type="text" placeholder="None" field={@form[val_splitter_key(field)]} />
              </td>
              <td class="px-2">
                <.input type="select" field={@form[order_key(field)]} options={@order_options[field]} />
              </td>
            </tr>
          </table>
        </div>

        <.table id="sample-csv-table" rows={@sample_rows}>
          <:col :let={row} :for={col <- @csv_headings} label={col}>
            <span :if={!(col in @mapped_fields)}>{Map.get(row, col)}</span>
            <div :if={col in @mapped_fields} class="space-y-4">
              <div :for={val <- Map.get(row, col) |> List.wrap()}>
                <div :if={is_list(val)}>
                  <span :for={inner <- val} class="px-1 py-1 bg-primary rounded-md mr-1">
                    {inner}
                  </span>
                </div>
                <span :if={!is_list(val)} class="px-1 py-1 bg-primary rounded-md mr-1">
                  {val}
                </span>
              </div>
            </div>
          </:col>
        </.table>

        <:actions>
          <.button class="btn btn-primary ml-auto" phx-disable-with="Saving...">
            Import rows
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset =
      Enum.reduce(assigns.fields, %{}, fn {key, _}, acc ->
        Map.merge(acc, %{
          key => nil,
          splitter_key(key) => nil,
          val_splitter_key(key) => nil,
          order_key(key) => nil
        })
      end)
      |> change(%{}, Keyword.keys(assigns.fields))

    order_options =
      Enum.map(assigns.fields, fn {key, def} ->
        keys = Keyword.keys(def.children)
        {key, key_options(keys) |> Enum.map(&Enum.join(&1, ", "))}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       csv_rows: [],
       sample_rows: [],
       csv_headings: [],
       mapped_fields: [],
       order_options: order_options,
       form: to_form(changeset, as: :csv_form)
     )
     |> allow_upload(:csv_file, accept: ~w(.csv), max_entries: 1)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"csv_form" => params}, socket) do
    changeset = change(socket.assigns.form.data, params, Keyword.keys(socket.assigns.fields))

    if changeset.valid? do
      mappers = get_mappers(socket.assigns.fields, params)

      sample_rows =
        apply_mapping(sample_rows(socket.assigns.csv_rows), mappers)

      {:noreply,
       socket
       |> assign(:sample_rows, sample_rows)
       |> assign(:mapped_fields, Map.keys(mappers))
       |> assign(:form, to_form(changeset, as: :csv_form, action: :validate))}
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :csv_form, action: :validate))}
    end
  end

  @impl true
  def handle_event("import", %{"csv_form" => params}, socket) do
    changeset = change(socket.assigns.form.data, params, Keyword.keys(socket.assigns.fields))

    if changeset.valid? do
      mappers = get_mappers(socket.assigns.fields, params)

      rows =
        apply_mapping(socket.assigns.csv_rows, mappers)
        |> Stream.map(&object_to_csv(changeset, &1, socket.assigns.fields))
        |> Enum.reject(&(map_size(&1) == 0))

      total = length(rows)

      case Context.create_multiple(
             socket.assigns.repo,
             socket.assigns.audit_context,
             socket.assigns.schema,
             rows
           ) do
        {:ok, count} when count == total ->
          {:noreply,
           socket
           |> put_flash(:info, "Imported #{count} rows")
           |> push_patch(to: socket.assigns.patch)}

        {:ok, count} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Failed to import #{socket.assigns.plural_name}, inserted (#{count}/#{total})"
           )
           |> push_patch(socket.assigns.patch)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Failed to import #{socket.assigns.plural_name}"
           )
           |> push_patch(socket.assigns.patch)}
      end
    else
      {:noreply, assign(socket, :form, to_form(changeset, as: :csv_form))}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("parse", _params, socket) do
    rows = parse_csv(socket)

    sample_rows = sample_rows(rows)
    headers = List.first(sample_rows) |> Map.keys()

    {:noreply,
     socket
     |> assign(:sample_rows, sample_rows)
     |> assign(:csv_rows, rows)
     |> assign(:csv_headings, headers)}
  end

  defp object_to_csv(changeset, object, fields) do
    Enum.reduce(fields, %{}, fn {k, def}, acc ->
      if field = Ecto.Changeset.get_field(changeset, k) do
        children_strings =
          Map.new(
            Keyword.keys(def.children),
            &{Atom.to_string(&1), &1}
          )

        order =
          Ecto.Changeset.get_field(changeset, order_key(k))
          |> String.split(", ")
          |> Stream.map(&Map.get(children_strings, &1))
          |> Enum.reject(&is_nil/1)

        val = Map.fetch!(object, field) |> Enum.map(&map_values(&1, order))
        Map.put(acc, k, val)
      else
        acc
      end
    end)
  end

  defp map_values(val, order) when is_list(val) do
    Enum.zip(order, val)
    |> Map.new()
  end

  defp map_values(val, _order), do: val

  defp get_mappers(fields, params) do
    fields
    |> Stream.map(fn {k, _} ->
      {Map.get(params, Atom.to_string(k)),
       {
         Map.get(
           params,
           Atom.to_string(splitter_key(k))
         ),
         Map.get(
           params,
           Atom.to_string(val_splitter_key(k))
         ),
         Map.get(
           params,
           Atom.to_string(order_key(k))
         )
       }}
    end)
    |> Stream.reject(fn
      {nil, _} -> true
      {"", _} -> true
      _ -> false
    end)
    |> Map.new()
  end

  defp key_options([]) do
    [[]]
  end

  defp key_options(list) do
    for h <- list, t <- key_options(list -- [h]), do: [h | t]
  end

  defp parse_csv(socket) do
    consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
      rows =
        path
        |> File.stream!()
        |> CSV.decode!(headers: true)
        |> Stream.reject(&Enum.all?(&1, fn {_k, v} -> v == "" end))
        |> Stream.map(&Map.reject(&1, fn {k, _v} -> k == "" end))
        |> Enum.to_list()

      {:ok, rows}
    end)
    |> List.first()
  end

  defp sample_rows(rows, num \\ 5) do
    rows
    |> Stream.take(num)
    |> Enum.map(&Map.delete(&1, ""))
  end

  defp apply_mapping(rows, mappers) do
    rows
    |> Stream.map(fn row ->
      Enum.reduce(mappers, row, fn {field, {splitter, val_splitter, _order}}, acc ->
        Map.update!(
          acc,
          field,
          &(apply_splitting(&1, splitter)
            |> apply_splitting(val_splitter))
        )
      end)
    end)
  end

  defp apply_splitting(val, ""), do: val

  defp apply_splitting(val, splitter) when is_list(val),
    do: Enum.map(val, &apply_splitting(&1, splitter))

  defp apply_splitting(val, splitter) do
    Regex.compile!(splitter, "i")
    |> Regex.split(val, trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp change(data, params, fields) do
    fields = Enum.flat_map(fields, &[&1, splitter_key(&1), val_splitter_key(&1), order_key(&1)])
    types = Enum.map(fields, &{&1, :string})

    Ecto.Changeset.change({data, types})
    |> Ecto.Changeset.cast(params, fields)
    |> then(fn changeset -> Enum.reduce(fields, changeset, &validate_regex/2) end)
  end

  defp validate_regex(field, changeset) when is_atom(field) do
    Ecto.Changeset.validate_change(changeset, field, fn ^field, val ->
      case Regex.compile(val, "i") do
        {:ok, _} ->
          []

        {:error, {reason, _}} ->
          [{field, List.to_string(reason)}]
      end
    end)
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp splitter_key(key), do: String.to_atom("#{key}_splitter")
  defp val_splitter_key(key), do: String.to_atom("#{key}_val_splitter")
  defp order_key(key), do: String.to_atom("#{key}_order")
end
