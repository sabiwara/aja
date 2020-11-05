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

  defmacro implement_inspect(module, prefix, suffix) do
    quote do
      import Inspect.Algebra

      def inspect(custom_map, opts) do
        open = color(unquote(prefix <> "%{"), :map, opts)
        sep = color(",", :map, opts)
        close = color(unquote("}" <> suffix), :map, opts)

        as_list = unquote(module).to_list(custom_map)

        container_doc(open, as_list, close, opts, traverse_fun(as_list, opts),
          separator: sep,
          break: :strict
        )
      end

      defp traverse_fun(list, opts) do
        if Inspect.List.keyword?(list) do
          &Inspect.List.keyword/2
        else
          sep = color(" => ", :map, opts)
          &to_map(&1, &2, sep)
        end
      end

      defp to_map({key, value}, opts, sep) do
        concat(concat(to_doc(key, opts), sep), to_doc(value, opts))
      end
    end
  end
end
