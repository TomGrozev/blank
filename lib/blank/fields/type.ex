defmodule Blank.Fields.Type do
  @moduledoc false

  # Adapters cannot call `Blank.Fields` (it lists every adapter), so the mapping lives here.

  @doc false
  @spec module_for_type(atom()) :: module()
  def module_for_type(:boolean), do: Blank.Fields.Boolean
  def module_for_type(:utc_datetime), do: Blank.Fields.DateTime
  def module_for_type(_), do: Blank.Fields.Text
end
