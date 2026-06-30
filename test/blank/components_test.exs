defmodule Blank.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.JS

  # Wrapper modules that use Phoenix.Component to provide ~H sigils.
  # Each wraps a Blank.Components call with inline content (no slot passing).

  defmodule IconWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.icon name={@name} class={@class} />
      """
    end
  end

  defmodule ButtonPrimary do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.button variant="primary">Click</Blank.Components.button>
      """
    end
  end

  defmodule ButtonNeutral do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.button variant="neutral">Click</Blank.Components.button>
      """
    end
  end

  defmodule ButtonError do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.button variant="error">Click</Blank.Components.button>
      """
    end
  end

  defmodule ButtonLink do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.button href="/foo">Link</Blank.Components.button>
      """
    end
  end

  defmodule ButtonNavigate do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.button navigate="/foo">Navigate</Blank.Components.button>
      """
    end
  end

  defmodule HeaderWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.header>
        My Title
      </Blank.Components.header>
      """
    end
  end

  defmodule ListWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.list>
        <:item title="First">Content 1</:item>
        <:item title="Second">Content 2</:item>
      </Blank.Components.list>
      """
    end
  end

  defmodule LoaderWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.loader name={@name} />
      """
    end
  end

  defmodule ModalWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.modal id={@id} show={@show} on_cancel={%JS{}}>
        Modal content
      </Blank.Components.modal>
      """
    end
  end

  defmodule FlashInfo do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.flash kind={:info} flash={@flash} />
      """
    end
  end

  defmodule FlashError do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.flash kind={:error} flash={@flash} />
      """
    end
  end

  defmodule FlashEmpty do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.flash kind={:info} flash={%{}} />
      """
    end
  end

  defmodule FlashGroupWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.flash_group flash={@flash} />
      """
    end
  end

  defmodule TableWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.table id="users" rows={@rows}>
        <:col :let={row} label="Name">{row.name}</:col>
      </Blank.Components.table>
      """
    end
  end

  defmodule ErrorWrapper do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <Blank.Components.error>is required</Blank.Components.error>
      """
    end
  end

  # Tests

  describe "icon/1" do
    test "renders a span with hero icon class" do
      html = render_component(&IconWrapper.render/1, %{name: "hero-home", class: "size-4"})
      assert html =~ "hero-home"
      assert html =~ "size-4"
    end

    test "renders with custom class" do
      html = render_component(&IconWrapper.render/1, %{name: "hero-x-mark", class: "w-5 h-5"})
      assert html =~ "hero-x-mark"
      assert html =~ "w-5 h-5"
    end
  end

  describe "button/1" do
    test "renders a button with primary variant" do
      html = render_component(&ButtonPrimary.render/1, %{})
      assert html =~ "<button"
      assert html =~ "btn"
      assert html =~ "btn-primary"
    end

    test "renders a button with neutral variant" do
      html = render_component(&ButtonNeutral.render/1, %{})
      assert html =~ "btn-neutral"
    end

    test "renders a button with error variant" do
      html = render_component(&ButtonError.render/1, %{})
      assert html =~ "btn-error"
    end

    test "renders a link when href is provided" do
      html = render_component(&ButtonLink.render/1, %{})
      assert html =~ "<a"
      assert html =~ "href=\"/foo\""
    end

    test "renders a link when navigate is provided" do
      html = render_component(&ButtonNavigate.render/1, %{})
      assert html =~ "<a"
      assert html =~ "data-phx-link"
    end
  end

  describe "header/1" do
    test "renders header with title text" do
      html = render_component(&HeaderWrapper.render/1, %{})
      assert html =~ "<header"
      assert html =~ "<h1"
      assert html =~ "My Title"
    end
  end

  describe "list/1" do
    test "renders a list with items" do
      html = render_component(&ListWrapper.render/1, %{})
      assert html =~ "First"
      assert html =~ "Content 1"
      assert html =~ "Second"
      assert html =~ "Content 2"
      assert html =~ "<ul"
    end
  end

  describe "loader/1" do
    test "renders loading spinner with humanized name" do
      html = render_component(&LoaderWrapper.render/1, %{name: "posts"})
      assert html =~ "Loading"
      assert html =~ "Posts"
      assert html =~ "animate-spin"
    end
  end

  describe "modal/1" do
    test "renders a modal with id" do
      html = render_component(&ModalWrapper.render/1, %{id: "m1", show: false})
      assert html =~ "id=\"m1\""
      assert html =~ "dialog"
      assert html =~ "aria-modal"
    end

    test "renders with phx-mounted when show is true" do
      html = render_component(&ModalWrapper.render/1, %{id: "m2", show: true})
      assert html =~ "phx-mounted"
    end
  end

  describe "flash/1" do
    test "renders info flash when flash map has info" do
      html = render_component(&FlashInfo.render/1, %{flash: %{"info" => "Welcome back!"}})
      assert html =~ "Welcome back!"
      assert html =~ "alert-info"
    end

    test "renders error flash when flash map has error" do
      html =
        render_component(&FlashError.render/1, %{flash: %{"error" => "Something went wrong"}})

      assert html =~ "Something went wrong"
      assert html =~ "alert-error"
    end

    test "renders nothing when flash map is empty" do
      html = render_component(&FlashEmpty.render/1, %{})
      refute html =~ "alert"
    end
  end

  describe "flash_group/1" do
    test "renders the flash group container" do
      html = render_component(&FlashGroupWrapper.render/1, %{flash: %{}})
      assert html =~ "flash-group"
      assert html =~ "aria-live"
    end

    test "renders flash messages when present" do
      html = render_component(&FlashGroupWrapper.render/1, %{flash: %{"info" => "Hello!"}})
      assert html =~ "Hello!"
    end
  end

  describe "table/1" do
    test "renders a table with rows and columns" do
      rows = [%{name: "Alice"}, %{name: "Bob"}]
      html = render_component(&TableWrapper.render/1, %{rows: rows})
      assert html =~ "<table"
      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "renders empty table with no rows" do
      html = render_component(&TableWrapper.render/1, %{rows: []})
      assert html =~ "<table"
      assert html =~ "Name"
    end
  end

  describe "error/1" do
    test "renders error message with icon" do
      html = render_component(&ErrorWrapper.render/1, %{})
      assert html =~ "is required"
      assert html =~ "text-error"
      assert html =~ "hero-exclamation-circle"
    end
  end

  describe "translate_error/1" do
    test "translates a simple error tuple" do
      result = Blank.Components.translate_error({"can't be blank", []})
      assert is_binary(result)
      assert result =~ "blank"
    end

    test "translates an error with interpolation" do
      result =
        Blank.Components.translate_error({"should be at least %{min} characters", [min: 3]})

      assert is_binary(result)
    end
  end

  describe "translate_errors/2" do
    test "translates errors for a specific field" do
      errors = [name: {"can't be blank", []}, email: {"is invalid", []}]
      result = Blank.Components.translate_errors(errors, :name)
      assert is_list(result)
      assert length(result) == 1
      assert hd(result) =~ "blank"
    end

    test "returns empty list when no errors for field" do
      errors = [email: {"is invalid", []}]
      result = Blank.Components.translate_errors(errors, :name)
      assert result == []
    end
  end
end
