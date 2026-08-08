defmodule Blank.Scope do
  @moduledoc """
  A struct passed to `Blank.Authorization.can?/3` carrying `resource_type` (required atom),
  `resource_id` (optional), and `extra` (consumer escape map).

  Encodes "the thing being acted on and its bounds".
  """

  @enforce_keys [:resource_type]
  defstruct [:resource_type, :resource_id, extra: %{}]

  @type t :: %__MODULE__{
          resource_type: atom(),
          resource_id: term() | nil,
          extra: map()
        }
end
