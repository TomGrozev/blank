if Code.ensure_loaded?(ArangoXEcto.Schema) do
  defmodule Blank.Accounts.Admin do
    use ArangoXEcto.Schema

    @derive {
      Blank.Schema,
      fields: [
        email: [searchable: true],
        hashed_password: [viewable: false],
        current_password: [module: Blank.Fields.Password, viewable: false],
        password: [module: Blank.Fields.Password]
      ],
      identity_field: :email,
      create_changeset: &__MODULE__.registration_changeset/2,
      update_changeset: &__MODULE__.registration_changeset/2
    }

    schema "blank_admins" do
      field(:email, :string)
      field(:password, :string, virtual: true, redact: true)
      field(:hashed_password, :string, redact: true)
      field(:current_password, :string, virtual: true, redact: true)

      timestamps(type: :utc_datetime)
    end

    defdelegate registration_changeset(admin, attrs, opts \\ []), to: Blank.Accounts.AdminBase
    defdelegate password_changeset(admin, attrs, opts \\ []), to: Blank.Accounts.AdminBase
    defdelegate valid_password?(admin, password), to: Blank.Accounts.AdminBase
    defdelegate validate_current_password(changeset, password), to: Blank.Accounts.AdminBase
  end
else
  defmodule Blank.Accounts.Admin do
    use Ecto.Schema

    @derive {
      Blank.Schema,
      fields: [
        email: [searchable: true],
        hashed_password: [viewable: false],
        current_password: [module: Blank.Fields.Password, viewable: false],
        password: [module: Blank.Fields.Password]
      ],
      identity_field: :email,
      create_changeset: &__MODULE__.registration_changeset/2,
      update_changeset: &__MODULE__.registration_changeset/2
    }

    schema "blank_admins" do
      field(:email, :string)
      field(:password, :string, virtual: true, redact: true)
      field(:hashed_password, :string, redact: true)
      field(:current_password, :string, virtual: true, redact: true)

      timestamps(type: :utc_datetime)
    end

    defdelegate registration_changeset(admin, attrs, opts \\ []), to: Blank.Accounts.AdminBase
    defdelegate password_changeset(admin, attrs, opts \\ []), to: Blank.Accounts.AdminBase
    defdelegate valid_password?(admin, password), to: Blank.Accounts.AdminBase
    defdelegate validate_current_password(changeset, password), to: Blank.Accounts.AdminBase
  end
end
