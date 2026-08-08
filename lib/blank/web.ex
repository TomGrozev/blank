defmodule Blank.Web do
  @moduledoc false

  @doc false
  @spec html() :: Macro.t()
  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  @doc false
  @spec controller() :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn
    end
  end

  @doc false
  @spec live_view() :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {Blank.LayoutView, :admin}

      unquote(html_helpers())
      unquote(flash_helpers())
    end
  end

  @doc false
  @spec live_component() :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc false
  @spec flash_helpers() :: Macro.t()
  def flash_helpers do
    quote do
      def handle_info(:clear_flash, socket) do
        {:noreply, clear_flash(socket)}
      end
    end
  end

  @doc false
  @spec field() :: Macro.t()
  def field do
    quote do
      use Phoenix.Component
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc false
  @spec stat() :: Macro.t()
  def stat do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: Blank.Gettext

      import Phoenix.HTML
      import Blank.Components
      import Blank.Components.Field
      import Blank.Components.JS

      alias Phoenix.LiveView.JS
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
