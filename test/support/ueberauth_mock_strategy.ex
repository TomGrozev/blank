defmodule Blank.Test.UeberauthMockStrategy do
  @moduledoc false
  use Ueberauth.Strategy, helpers: false

  def handle_request!(_conn) do
    # Mock implementation - tests inject assigns directly
    :ok
  end

  def handle_callback!(conn) do
    conn
  end

  def handle_cleanup!(conn) do
    conn
  end
end
