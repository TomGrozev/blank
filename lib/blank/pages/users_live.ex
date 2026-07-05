defmodule Blank.Pages.UsersLive do
  @moduledoc false
  alias Blank.Accounts.User

  use Blank.AdminPage,
    schema: User,
    icon: "hero-user",
    index_fields: [:id, :email],
    name: "user",
    plural_name: "users"
end
