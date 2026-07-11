defmodule Blank.Plugs.Auth do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller

  alias Blank.Accounts
  alias Blank.Accounts.UserToken

  @doc """
  Returns whether local login is enabled based on the `:local_login` config.

  Config values:
  - `:enabled` — local login always available (default)
  - `:dev_only` — local login available only in `:dev` and `:test` environments
  - `:disabled` — local login never available
  """
  def local_login_enabled? do
    config = Application.get_env(:blank, :auth, [])

    case Keyword.get(config, :local_login, :enabled) do
      :enabled -> true
      :disabled -> false
      :dev_only -> Mix.env() in [:dev, :test]
    end
  end

  @doc """
  Returns the idle timeout duration as seconds.

  Defaults to 4 hours if not configured.
  Config format: `{integer, :hours | :days | :minutes}`
  """
  def idle_timeout do
    config = Application.get_env(:blank, :auth, [])
    timeout = Keyword.get(config, :idle_timeout, {4, :hours})
    duration_to_seconds(timeout)
  end

  @doc """
  Returns the absolute lifetime duration as seconds.

  Defaults to 60 days if not configured.
  Config format: `{integer, :hours | :days | :minutes}`
  """
  def absolute_lifetime do
    config = Application.get_env(:blank, :auth, [])
    lifetime = Keyword.get(config, :absolute_lifetime, {60, :days})
    duration_to_seconds(lifetime)
  end

  @doc """
  Checks if a token has expired based on idle timeout and absolute lifetime.

  Returns :ok if valid, or {:error, reason} if the token should be invalidated.
  """
  def check_token_validity(token_record) do
    with :ok <- check_not_expired(token_record) do
      check_not_idle_expired(token_record)
    end
  end

  defp check_not_expired(token_record) do
    now = DateTime.utc_now()
    absolute_seconds = absolute_lifetime()
    absolute_deadline = DateTime.add(token_record.inserted_at, absolute_seconds, :second)

    if DateTime.compare(now, absolute_deadline) != :lt do
      {:error, :expired}
    else
      :ok
    end
  end

  defp check_not_idle_expired(token_record) do
    case token_record.last_activity_at do
      nil ->
        :ok

      last_activity ->
        now = DateTime.utc_now()
        idle_seconds = idle_timeout()
        idle_deadline = DateTime.add(last_activity, idle_seconds, :second)

        if DateTime.compare(now, idle_deadline) != :lt do
          {:error, :idle_expired}
        else
          :ok
        end
    end
  end

  defp duration_to_seconds({value, unit}) do
    case unit do
      :minutes -> value * 60
      :hours -> value * 3600
      :days -> value * 86_400
    end
  end

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_blank_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in(conn, user, params \\ %{}) do
    audit_params = %{
      email: user.email,
      type: if(is_nil(user.provider), do: "local", else: "ueberauth"),
      provider: user.provider
    }

    audit_context = %{conn.assigns[:audit_context] | user: user}
    Blank.Audit.log!(audit_context, "accounts.login", audit_params)

    token = Accounts.generate_user_session_token(user)
    return_to = get_session(conn, :return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out(conn) do
    user = conn.assigns[:current_user]
    user_token = get_session(conn, :user_token)

    if user do
      audit_context = %{conn.assigns[:audit_context] | user: user}

      Blank.Audit.log!(audit_context, "accounts.logout", %{
        email: user.email,
        provider: user.provider
      })
    end

    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      endpoint = Application.fetch_env!(:blank, :endpoint)
      endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    prefix = conn.private.phoenix_router.__blank_prefix__()

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: prefix)
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    case user_token do
      nil ->
        assign(conn, :current_user, nil)

      token ->
        token_record = repo().one(UserToken.by_token_and_context_query(token, "session"))
        conn = handle_token_record(conn, token, token_record)
        conn
    end
  end

  defp handle_token_record(conn, _token, nil) do
    conn
    |> configure_session(drop: true)
    |> assign(:current_user, nil)
  end

  defp handle_token_record(conn, token, token_record) do
    case check_token_validity(token_record) do
      :ok ->
        UserToken.touch_last_activity(token_record)
        user = Accounts.get_user_by_session_token(token)
        assign(conn, :current_user, user)

      {:error, _reason} ->
        Accounts.delete_user_session_token(token)

        conn
        |> configure_session(drop: true)
        |> assign(:current_user, nil)
    end
  end

  defp repo, do: Application.fetch_env!(:blank, :repo)

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      case conn.cookies[@remember_me_cookie] do
        nil ->
          {nil, conn}

        token ->
          {token, put_token_in_session(conn, token)}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule Blank.PageLive do
        use Blank.Web, :live_view

        on_mount {Blank.Plugs.Auth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{Blank.Plugs.Auth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)
    prefix = socket.router.__blank_prefix__()

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: Path.join(prefix, "log_in"))

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      case session["user_token"] do
        nil -> nil
        user_token -> find_valid_user(user_token)
      end
    end)
  end

  defp find_valid_user(user_token) do
    case repo().one(UserToken.by_token_and_context_query(user_token, "session")) do
      nil -> nil
      token_record -> resolve_token(user_token, token_record)
    end
  end

  defp resolve_token(user_token, token_record) do
    case check_token_validity(token_record) do
      :ok ->
        UserToken.touch_last_activity(token_record)
        Accounts.get_user_by_session_token(user_token)

      {:error, _reason} ->
        Accounts.delete_user_session_token(user_token)
        nil
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    prefix = conn.private.phoenix_router.__blank_prefix__()

    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Path.join(prefix, "log_in"))
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(conn), do: conn.private.phoenix_router.__blank_prefix__()
end
