# Glossary

Blank has a lot of domain-specific terms. This page explains each one in plain language.

If you're new to Blank, "Admin Page" and "Blank Schema" are the two concepts you'll interact with most. Everything else builds on top of them.

---

## Core Concepts

### Admin

A person who logs into the admin panel to manage the application. Also called an "administrator" or "operator."

_See: [Authentication](Authentication.md)_

### Admin Page

A page in the admin panel for managing a specific resource — like Users, Orders, or Products. You create an admin page by writing a module with `use Blank.AdminPage`.

_See: [Getting Started](Getting Started.md)_

### AdminPanel

The top-level module that wires the admin panel into your Phoenix app. You use it in your router with the `blank_admin` macro to mount all admin routes at once.

_See: [Routing](../howtos/Routing.md)_

### Blank Schema

The bridge between your Ecto schema and the admin panel. You create one by deriving `Blank.Schema` on your schema module, which tells Blank how to display, edit, and validate that resource.

_See: [Schema Options](../cheatsheets/Schema Options.md)_

### Field

A single piece of data in an admin page — for example, a user's name, email, or status. Every field has a type (text, boolean, date, etc.) and can be customized with options.

_See: [Field Options](../cheatsheets/Field Options.md)_

### User

A person who can log in to the admin panel. Users are stored in the `blank_users` table. A user can authenticate either with a local email and password or through an external identity provider (like Google or GitHub).

_See: [Authentication](Authentication.md)_

---

## Authentication

### Local Login

Authentication with an email and password, stored directly in the `blank_users` table. You can enable it, disable it, or set it to dev-only mode (for development environments).

_See: [Authentication](Authentication.md)_

### Ueberauth

An authentication framework for Phoenix that lets users log in through external identity providers — such as GitHub, Google, or any OAuth/OIDC service. Blank uses ueberauth to handle third-party logins.

_See: [Authentication](Authentication.md)_

### Role Mapper

A module that translates the claims from an identity provider (returned by ueberauth) into a list of roles. It runs on every login and replaces the user's current roles with the ones it produces.

_See: [Role Mappers](Role Mappers.md)_

### Bootstrap

The one-time step of creating the very first admin user. You do this from the command line with `mix blank.user.new --roles system_admin`. Until bootstrap happens, no one can log in.

_See: [Authentication](Authentication.md#bootstrap)_

---

## Authorization

### Authorization

The system that decides what an admin is allowed to do. It checks the admin's roles against a policy module on every action (viewing, creating, editing, or deleting a resource).

_See: [Authorization](Authorization.md)_

### Role

A label that represents what an admin can do — for example, `:member`, `:system_admin`, or `:payment_manager`. Roles are atoms in code and stored as strings in the database.

_See: [Authorization](Authorization.md)_

### Policy Module

A module you write that defines the rules: "who can do what." It receives the user, the action, and the resource being acted on, and returns `true` or `false`. You build it on top of Blank's built-in `DefaultPolicy`.

_See: [Authorization](Authorization.md)_

### DefaultPolicy

The built-in fallback policy. It denies everything — unless the user has the `:system_admin` role. If you don't write a custom policy module, this is what runs by default.

_See: [Authorization](Authorization.md)_

### Scope

A struct that describes what's being acted on: the type of resource (`:user`, `:order`), an optional resource ID, and any extra context you need. It's passed to the policy module so it knows exactly what's at stake.

_See: [Authorization](Authorization.md)_

### Break-Glass

The `:system_admin` role. It bypasses all authorization checks — a `:system_admin` can always do anything, no matter what the policy module says. This is useful for emergency access or initial setup, but should be assigned sparingly.

_See: [Authorization](Authorization.md#the-break-glass-system_admin-role)_

---

## Audit & Logging

### Audit Log

A permanent record of every change made through the admin panel — creates, updates, and deletes. Each log entry captures who did it, what they did, when, and to which resource.

_See: [Audit Logging](../howtos/Audit Logging.md)_

### Audit Context

A module that gathers information from the request — like the current user and their IP address — and makes it available so every audit log entry can include that context.

_See: [Audit Logging](../howtos/Audit Logging.md)_

---

## Data & Export

### Exporter

A module that turns a list of records into a downloadable file — like a CSV spreadsheet or a QR code. You write an exporter by implementing the `Blank.Exporter` behaviour.

_See: [Custom Exporter](../howtos/Custom Exporter.md)_

### Stats

Summary numbers displayed at the top of an admin page — for example, the total number of users or the total revenue. You provide a stats module and Blank renders them as cards above the data table.

_See: [Custom Stats](../howtos/Custom Stats.md)_
