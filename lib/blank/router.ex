defmodule Blank.Router do
  @moduledoc """
  Provides routing options for blank admin panel.

  The two macros in this function are mearly wrappers around regular Phoenix
  routing. Below is an example of how it can be used.

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import Blank.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]
        end

        blank_admin "/admin" do
          admin_page("/products", MyAppWeb.Admin.ProductsLive)
        end
      end
  """

  @doc """
  Defines the Blank routes.

  Expects the `path` the admin panel will be mounted at
  and a set of options. You can then link to the home of the admin panel
  directly.

      <a href={~p"/admin"}>Admin Panel</a>

  The options supplied in the do block define each admin page, see
  `admin_page/2`.

  ## Options

  These options are generally not required and only needed for some advanced
  setups.

    * `:live_session_name` - Configures the name of the live session. Defaults
      to `:blank_admin_panel`
    * `:on_mount` - Declares a custom list of `Phoenix.LiveView.on_mount/1`
      callbacks to add to the admin panel's `Phoenix.LiveView.Router.live_session/3`.
      A single value may also be declared.

  ## Examples

      defmodule MyAppWeb.Router do
        ...

        blank_admin "/admin" do
          admin_page("/products", MyAppWeb.Admin.ProductsLive)
          ...
        end

        ...
      end

  """
  defmacro blank_admin(path, opts \\ [], do: block) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    scope =
      quote do
        import Phoenix.LiveView.Router
        import Blank.Plugs.Auth
        import Blank.Plugs.AuditContext

        {session_name, session_opts} =
          Blank.Router.__options__(unquote(opts))

        path = unquote(path)

        pipeline :blank_browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug :put_root_layout, html: {Blank.LayoutView, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_headers
          plug :fetch_current_admin
          plug :fetch_audit_context
        end

        scope path, alias: false, as: false do
          pipe_through [:blank_browser, :redirect_if_admin_is_authenticated]

          live_session :blank_redirect_if_admin_is_authenticated,
            root_layout: {Blank.LayoutView, :root},
            layout: {Blank.LayoutView, :basic},
            on_mount: [
              {Blank.Plugs.Auth, :redirect_if_admin_is_authenticated},
              Blank.Plugs.AuditContext
            ] do
            live("/log_in", Blank.Pages.LoginLive, :new)
          end

          post "/log_in", Blank.Controllers.SessionController, :create
        end

        scope path, alias: false, as: false do
          pipe_through [:blank_browser, :require_authenticated_admin]

          live_session session_name, session_opts do
            live("/", Blank.Pages.HomeLive, :home)
            live("/profile", Blank.Pages.ProfileLive, :profile)
            live("/settings", Blank.Pages.SettingsLive, :settings)
            live("/audit", Blank.Pages.AuditLogLive, :audit)

            get("/download", Blank.Controllers.ExportController, :download)
            get("/qrcode", Blank.Controllers.ExportController, :qr_code)

            admin_page("/admins", Blank.Pages.AdminsLive)

            unquote(block)
          end

          delete "/log_out", Blank.Controllers.SessionController, :delete
        end
      end

    quote do
      Module.register_attribute(__MODULE__, :blank_admin_modules, accumulate: true)

      unquote(scope)

      unless Module.get_attribute(__MODULE__, :blank_prefix) do
        @blank_prefix Phoenix.Router.scoped_path(__MODULE__, path)
                      |> String.replace_suffix("/", "")
        def __blank_prefix__, do: @blank_prefix
      end

      def __blank_modules__, do: @blank_admin_modules
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:blank_admin, 2}})

  defp expand_alias(other, _env), do: other

  @doc false
  def __options__(options) do
    on_mount =
      Enum.concat(options[:on_mount] || [], [
        Blank.Nav,
        {Blank.Plugs.Auth, :ensure_authenticated},
        Blank.Plugs.AuditContext
      ])

    {
      options[:live_session_name] || :blank_admin_panel,
      [
        on_mount: on_mount,
        root_layout: {Blank.LayoutView, :root}
      ]
    }
  end

  @doc """
  Defines an admin page for a resource

  This must be used within the do block of the `blank_admin/3` function.

  ## Parameters

    * `path` - the path to the route
    * `module` - the admin page module

  ## Examples

      blank_admin "/admin" do
        ...
        admin_page("/products", MyAppWeb.Admin.ProductsLive)
        admin_page("/people", MyAppWeb.Admin.PeopleLive)
        admin_page("/posts", MyAppWeb.Admin.PostsLive)
        ...
      end
  """
  defmacro admin_page(path, module) do
    quote bind_quoted: binding() do
      Phoenix.Router.scoped_alias(__MODULE__, module)
      |> then(&Module.put_attribute(__MODULE__, :blank_admin_modules, {path, &1}))

      live("#{path}/", module, :index)
      live("#{path}/new", module, :new)
      live("#{path}/import", module, :import)
      live("#{path}/export", module, :export)
      live("#{path}/:id", module, :show)
      live("#{path}/:id/edit", module, :edit)
    end
  end
end
