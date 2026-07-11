defmodule Blank.Stats.ValueTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  alias Blank.Stats.Value
  alias Phoenix.LiveView.AsyncResult

  describe "query/3" do
    test "adds a one/3 step to the Ecto.Multi" do
      multi = Ecto.Multi.new()
      query = from(p in TestApp.Blog.Post)

      result = Value.query(multi, {:count, []}, query)

      assert %Ecto.Multi{} = result

      # The multi should contain a step named :count
      steps = Ecto.Multi.to_list(result)
      assert Keyword.has_key?(steps, :count)
    end
  end

  describe "render/1" do
    test "renders the async result template" do
      assigns = %{
        name: "Total Posts",
        value: %AsyncResult{result: 42}
      }

      rendered = Value.render(assigns)

      assert %Phoenix.LiveView.Rendered{} = rendered
    end

    test "renders with loading state" do
      assigns = %{
        name: "Total Posts",
        value: %AsyncResult{}
      }

      rendered = Value.render(assigns)

      assert %Phoenix.LiveView.Rendered{} = rendered
    end
  end
end
