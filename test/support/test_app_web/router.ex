defmodule TestAppWeb.Router do
  use Phoenix.Router
  import Blank.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Blank.LayoutView, :root}
    plug :put_secure_browser_headers
  end

  scope "/test" do
    pipe_through :browser

    live "/searchable_select", TestAppWeb.TestSearchableSelectLive, :index
  end

  blank_admin "/admin" do
    admin_page "/posts", TestAppWeb.Admin.PostLive
    get "/authorize_test", TestAppWeb.Admin.AuthorizeTestController, :index
    post "/authorize_test", TestAppWeb.Admin.AuthorizeTestController, :create
  end
end
