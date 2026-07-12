# Blank Demo App

A minimal but complete Phoenix application that demonstrates Blank's features. This is a standalone app that you can clone and run to see Blank in action.

## Features Demonstrated

- **Two admin pages** — Users and Orders with full CRUD
- **Blank.Schema derive** — Custom field definitions with searchable/sortable options
- **Custom stats** — Total counts and a custom revenue calculator
- **Authorization policy** — Role-based access control for different resources
- **Audit logging** — Automatic tracking of all mutations
- **Ueberauth integration** — GitHub login (configured but requires OAuth credentials)
- **BelongsTo relationships** — Orders linked to Users with display fields

## Setup

### Prerequisites

- Elixir ~> 1.14
- PostgreSQL
- Mix

### Steps

1. **Install dependencies:**

   ```bash
   mix deps.get
   ```

2. **Create the database and run migrations:**

   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

3. **Create a bootstrap admin user:**

   ```bash
   mix blank.user.new --email admin@example.com --password "password123" --roles system_admin
   ```

4. **Start the server:**

   ```bash
   mix phx.server
   ```

5. **Visit the admin panel:**

   Open [http://localhost:4000/admin](http://localhost:4000/admin) and log in with the credentials you created.

## What's Included

### Admin Pages

- **Users** (`/admin/users`) — Manage user accounts with name, email, and status fields
- **Orders** (`/admin/orders`) — Manage orders with customer name, total amount, status, and user association

### Schema Features

- **Searchable fields** — Search users by name/email, orders by customer name
- **Sortable fields** — Sort by name, status, total amount
- **Identity fields** — Custom display names for records
- **BelongsTo relationships** — Orders show associated user names

### Stats

- **User stats** — Total users, active users count
- **Order stats** — Total orders, revenue from completed orders (custom stats module)

### Authorization

Custom policy module demonstrating role-based access:

- `:system_admin` — Full access (break-glass)
- `:payment_manager` — Can manage orders
- `:content_editor` — Can update users
- `:member` — Read-only access to orders and users

### Audit Logging

All create, update, and delete operations are automatically logged with:
- Acting admin
- Action type
- Resource details
- IP address

## Configuration

### Local Login

In development, local email/password login is available. In production, only ueberauth providers are enabled.

### GitHub OAuth

To enable GitHub login:

1. Create a GitHub OAuth App
2. Set environment variables:

   ```bash
   export GITHUB_CLIENT_ID=your_client_id
   export GITHUB_CLIENT_SECRET=your_client_secret
   ```

3. Update `config/runtime.exs` with the credentials

## Next Steps

- See the [Blank guides](https://hexdocs.pm/blank) for detailed documentation
- Try adding a custom field type
- Implement a custom exporter
- Configure a real ueberauth provider
- Add more admin pages for your own schemas
