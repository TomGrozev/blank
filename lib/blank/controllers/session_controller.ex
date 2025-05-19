defmodule Blank.Controllers.SessionController do
  use Blank.Web, :controller

  alias Blank.Accounts
  alias Blank.Plugs.Auth

  def create(conn, %{"_action" => "password_updated"} = params) do
    prefix = conn.private.phoenix_router.__blank_prefix__()

    conn
    |> put_session(:admin_return_to, Path.join(prefix, "/profile/settings"))
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"admin" => admin_params}, info) do
    %{"email" => email, "password" => password} = admin_params

    if admin = Accounts.get_admin_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> Auth.log_in(admin, admin_params)
    else
      prefix = conn.private.phoenix_router.__blank_prefix__()

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: Path.join(prefix, "/log_in"))
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> Auth.log_out()
  end
end
