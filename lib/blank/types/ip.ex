defmodule Blank.Types.IP do
  @moduledoc """
  Implements Ecto.Type behavior for storing IP (either v4 or v6) data that originally comes as tuples.
  """

  use Ecto.Type

  @doc """
  Defines what internal database type is used.
  """
  def type, do: :string

  @doc """
  Cast to an IP tuple
  """
  def cast(value) when is_binary(value), do: load(value)
  def cast(value) when is_tuple(value), do: {:ok, value}

  @doc """
  Loads the IP as string from the database and coverts to a tuple.
  """
  def load(value) do
    value
    |> to_charlist()
    |> :inet.parse_address()
  end

  @doc """
  Uses itself in an embed
  """
  def embed_as(_), do: :self

  @doc """
  Checks if the two IPs are equal
  """
  def equal?(ip1, ip2), do: String.equivalent?(ip1, ip2)

  @doc """
  Receives IP as a tuple and converts to string. In case IP is not a tuple returns an error.
  """
  def dump(value) when is_tuple(value) do
    ip =
      value
      |> :inet.ntoa()
      |> to_string()

    {:ok, ip}
  end

  def dump(_), do: :error
end
