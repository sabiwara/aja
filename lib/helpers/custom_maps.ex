defmodule A.Helpers.CustomMaps do
  @moduledoc false

  @compile {:inline, get_and_update: 3, get_and_update!: 3, do_get_and_update: 4}

  @doc false
  def get_and_update(%map_module{} = custom_map, key, fun) do
    current = map_module.get(custom_map, key)

    do_get_and_update(custom_map, key, fun, current)
  end

  @doc false
  def get_and_update!(%map_module{} = custom_map, key, fun) do
    current = map_module.fetch!(custom_map, key)

    do_get_and_update(custom_map, key, fun, current)
  end

  defp do_get_and_update(%map_module{} = custom_map, key, fun, current) do
    case fun.(current) do
      {get, update} ->
        {get, map_module.put(custom_map, key, update)}

      :pop ->
        {current, map_module.delete(custom_map, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end
end
