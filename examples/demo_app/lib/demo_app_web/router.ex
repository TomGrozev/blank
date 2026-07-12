defmodule DemoAppWeb.Router do
  @moduledoc """
  Router for the DemoApp.

  Demonstrates how to set up Blank's admin panel with multiple admin pages.
  """
  use DemoAppWeb, :router
  import Blank.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Blank.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", DemoAppWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Blank admin panel routes
  blank_admin "/admin" do
    admin_page "/users", DemoAppWeb.Admin.UserPage
    admin_page "/orders", DemoAppWeb.Admin.OrderPage
  end
end
