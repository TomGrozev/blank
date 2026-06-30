defmodule TestAppWeb.TestNavRouter do
  @moduledoc false
  def __blank_prefix__, do: "/admin"
  def __blank_modules__, do: [{"/posts", TestAppWeb.Admin.PostLive}]
end

defmodule Blank.NavTest do
  use ExUnit.Case, async: true

  setup do
    # Ensure endpoint is started for persistent_term lookup
    try do
      start_supervised!(TestAppWeb.Endpoint)
    rescue
      _ -> :ok
    end

    :ok
  end

  defp build_socket do
    %Phoenix.LiveView.Socket{
      id: "test-socket",
      router: TestAppWeb.TestNavRouter,
      view: TestAppWeb.Admin.PostLive,
      endpoint: TestAppWeb.Endpoint,
      assigns: %{__changed__: %{}},
      private: %{
        lifecycle: %Phoenix.LiveView.Lifecycle{}
      }
    }
  end

  test "on_mount/4 returns {:cont, socket} with main_links and bottom_links assigned" do
    socket = build_socket()

    {:cont, socket} = Blank.Nav.on_mount(:default, %{}, %{}, socket)

    assert is_list(socket.assigns.main_links)
    assert is_list(socket.assigns.bottom_links)
    assert socket.assigns.path_prefix == "/admin"
  end

  test "on_mount/4 main_links includes Home and dynamic admin pages" do
    socket = build_socket()

    {:cont, socket} = Blank.Nav.on_mount(:default, %{}, %{}, socket)

    # Home link should be present
    home_link = Enum.find(socket.assigns.main_links, &(&1.key == :home))
    assert home_link != nil
    assert home_link.text == "Home"
    assert home_link.url =~ "/admin"

    # Dynamic links from admin pages should be present
    post_link = Enum.find(socket.assigns.main_links, &(&1.key == :post))
    assert post_link != nil
    assert post_link.text == "Posts"
    assert post_link.url =~ "/admin/posts"
  end

  test "on_mount/4 bottom_links includes audit, settings, profile" do
    socket = build_socket()

    {:cont, socket} = Blank.Nav.on_mount(:default, %{}, %{}, socket)

    keys = Enum.map(socket.assigns.bottom_links, & &1.key)
    assert :audit in keys
    assert :settings in keys
    assert :profile in keys

    # All bottom links should have /admin prefix
    Enum.each(socket.assigns.bottom_links, fn link ->
      assert link.url =~ "/admin"
    end)
  end

  test "on_mount/4 attaches handle_params hook" do
    socket = build_socket()

    {:cont, socket} = Blank.Nav.on_mount(:default, %{}, %{}, socket)

    # The hook should be attached in the lifecycle
    lifecycle = socket.private.lifecycle
    hook_ids = Enum.map(lifecycle.handle_params, & &1.id)
    assert :active_tab in hook_ids
  end
end
