defmodule Blank.Plugs.Authorize do
  @moduledoc """
  A Phoenix plug for coarse authorization checks on non-LiveView routes.

  Runs `Blank.Authorization.can?(current_user, action, scope)` at plug time
  and halts with HTTP 403 on denial. Mirrors the coarse-gate pattern LiveViews
  get from the `on_mount` hook.

  ## Usage

      plug Blank.Plugs.Authorize, action: :create, resource_type: :order

  Or with Phoenix's `when` guard for action-specific application (note the brackets around opts):

      plug Blank.Plugs.Authorize, [action: :list, resource_type: :post] when action in [:index]
      plug Blank.Plugs.Authorize, [action: :create, resource_type: :post] when action in [:create]

  ## Options

    * `:action` (required) — the coarse action atom (`:create`, `:list`, `:read`, etc.)
    * `:resource_type` (required) — the resource type atom for the `Blank.Scope`

  ## Behavior

  Reads `current_user` from `conn.assigns`. Builds `%Blank.Scope{resource_type: resource_type}`.
  Calls `Blank.Authorization.can?(user, action, scope)`. On denial, halts with HTTP 403
  and a plain-text "Forbidden" body. On allow, passes the connection through unchanged.

  Fine-grained resource-specific checks (e.g. `:show` of a particular record) remain
  explicit `can?` calls inside controller actions — this plug only handles coarse gates.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts) do
    action = Keyword.fetch!(opts, :action)
    resource_type = Keyword.fetch!(opts, :resource_type)
    %{action: action, resource_type: resource_type}
  end

  @impl Plug
  def call(conn, %{action: action, resource_type: resource_type}) do
    user = conn.assigns[:current_user]

    scope = %Blank.Scope{resource_type: resource_type}

    if user && Blank.Authorization.can?(user, action, scope) do
      conn
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(403, "Forbidden")
      |> halt()
    end
  end
end
