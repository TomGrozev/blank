defmodule TestAppWeb.Admin.AuthorizeTestController do
  @moduledoc false
  use Phoenix.Controller
  use Blank.Authorization, :test_resource

  plug Blank.Plugs.Authorize,
       [action: :list, resource_type: :test_resource] when action in [:index]

  plug Blank.Plugs.Authorize,
       [action: :create, resource_type: :test_resource] when action in [:create]

  def index(conn, _params) do
    # Demonstrate that can?/3 is available unqualified via use Blank.Authorization
    scope = %Blank.Scope{resource_type: :test_resource}
    result = can?(conn.assigns[:current_user], :list, scope)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "index: authorized=#{result}")
  end

  def create(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "create: ok")
  end
end
