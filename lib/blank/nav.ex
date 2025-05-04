defmodule Blank.Nav do
  import Phoenix.LiveView
  import Phoenix.Component

  @links %{
    main: [
      %{
        text: "Home",
        icon: "hero-home",
        url: "/",
        key: :home,
        module: Blank.Pages.HomeLive
      }
    ],
    bottom: [
      %{
        text: "Settings",
        icon: "hero-cog-6-tooth",
        url: "/settings",
        key: :settings,
        module: Blank.Pages.SettingsLive
      },
      %{
        text: "Profile",
        icon: "hero-user",
        url: "/profile",
        key: :profile,
        module: Blank.Pages.ProfileLive
      }
    ]
  }

  def on_mount(:default, _params, _session, socket) do
    prefix = socket.router.__blank_prefix__()
    modules = socket.router.__blank_modules__()

    dynamic_links = Enum.map(modules, &generate_link_definition(socket, prefix, &1))

    main_links =
      Enum.map(@links.main, fn link ->
        Map.update!(link, :url, &route_path(socket, prefix, &1))
      end) ++ dynamic_links

    bottom_links =
      Enum.map(@links.bottom, fn link ->
        Map.update!(link, :url, &route_path(socket, prefix, &1))
      end)

    {:cont,
     socket
     |> attach_hook(:active_tab, :handle_params, &set_active_tab/3)
     |> assign(:path_prefix, prefix)
     |> assign(:main_links, main_links)
     |> assign(:bottom_links, bottom_links)}
  end

  defp route_path(socket, prefix, url) do
    Phoenix.VerifiedRoutes.unverified_path(
      socket,
      socket.router,
      Path.join(prefix, url)
    )
  end

  defp set_active_tab(_params, _url, socket) do
    active_link = get_link(socket)

    {:cont, assign(socket, :active_link, active_link)}
  end

  defp get_link(socket) do
    module = socket.view

    Enum.find_value(socket.assigns.main_links ++ socket.assigns.bottom_links, fn
      %{module: ^module} = link ->
        link

      _ ->
        false
    end)
  end

  defp generate_link_definition(socket, prefix, {path, module}) do
    %{
      text: String.capitalize(module.config(:plural_name)),
      icon: module.config(:icon),
      url: route_path(socket, prefix, path),
      key: module.config(:key),
      module: module
    }
  end
end
