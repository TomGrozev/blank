defmodule Blank.Types.IP do
  @moduledoc """
  Ecto type for storing IP addresses (v4 or v6).

  Stores IPs as strings in the database and casts them to/from
  `:inet` tuples (`{a, b, c, d}` for IPv4, `{a, b, c, d, e, f, g, h}` for
  IPv6) for in-memory use.
  """

  ### Implements Ecto.Type behavior for storing IP (either v4 or v6) data that originally comes as tuples.

  use Ecto.Type

  @doc """
  Defines what internal database type is used.
  """
  @spec type() :: :string
  def type, do: :string

  @doc """
  Cast to an IP tuple
  """
  @spec cast(any()) :: {:ok, :inet.ip_address()} | :error
  def cast(value) when is_binary(value), do: load(value)
  def cast(value) when is_tuple(value), do: {:ok, value}

  @doc """
  Loads the IP as string from the database and coverts to a tuple.
  """
  @spec load(String.t()) :: {:ok, :inet.ip_address()} | {:error, term()}
  def load(value) do
    value
    |> to_charlist()
    |> :inet.parse_address()
  end

  @doc """
  Uses itself in an embed
  """
  @spec embed_as(any()) :: :self
  def embed_as(_), do: :self

  @doc """
  Checks if the two IPs are equal
  """
  @spec equal?(:inet.ip_address(), :inet.ip_address()) :: boolean()
  def equal?(ip1, ip2), do: ip1 == ip2

  @doc """
  Receives IP as a tuple and converts to string. In case IP is not a tuple returns an error.
  """
  @spec dump(:inet.ip_address()) :: {:ok, String.t()} | :error
  def dump(value) when is_tuple(value) do
    ip =
      value
      |> :inet.ntoa()
      |> to_string()

    {:ok, ip}
  end

  def dump(_), do: :error
end
