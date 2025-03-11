defmodule Blank.LayoutView do
  @moduledoc false
  use Blank.Web, :html
  alias Phoenix.LiveView.JS

  embed_templates "layouts/*"

  defp show_side_bar(js \\ %JS{}) do
    js
    |> JS.show(to: "#sidebar-wrapper")
    |> JS.show(
      to: "#sidebar-close-btn",
      display: "flex",
      transition: {"ease-in-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#sidebar-menu",
      display: "flex",
      transition:
        {"transition ease-in-out duration-300 transform", "-translate-x-full", "translate-x-0"}
    )
    |> JS.show(
      to: "#sidebar-backdrop",
      transition: {"transition-opacity ease-linear duration-300", "opacity-0", "opacity-100"}
    )
  end

  defp hide_side_bar(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#sidebar-close-btn",
      transition: {"ease-in-out duration-300", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#sidebar-menu",
      transition:
        {"transition ease-in-out duration-300 transform", "translate-x-0", "-translate-x-full"}
    )
    |> JS.hide(
      to: "#sidebar-backdrop",
      transition: {"transition-opacity ease-linear duration-300", "opacity-100", "opacity-0"}
    )
    |> JS.hide(to: "#sidebar-wrapper", time: 800, transition: "delay-1000")
  end
end
