defmodule Blank.Pages.AdminsLive do
  alias Blank.Accounts.Admin

  use Blank.AdminPage,
    schema: Admin,
    icon: "hero-user",
    index_fields: [:id, :email],
    name: "admin",
    plural_name: "admins"
end
