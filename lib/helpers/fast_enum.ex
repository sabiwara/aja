defmodule A.FastEnum do
  @moduledoc false

  # dialyzer([{nowarn_function, [to_list/1]}, call_without_opaque]).

  @dialyzer {:nowarn_function, [to_list: 1]}
  @compile {:inline, to_list: 1}
  @spec to_list(Enumerable.t()) :: list()
  def to_list(list) when is_list(list), do: list

  # TODO: see if can speedup ranges
  # TODO: investigate a Listable protocol instead

  for module <- [MapSet, A.Vector, A.OrdMap] do
    def to_list(%unquote(module){} = instance) do
      unquote(module).to_list(instance)
    end
  end

  def to_list(enumerable), do: Enum.to_list(enumerable)
end
