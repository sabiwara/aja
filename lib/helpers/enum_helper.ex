defmodule Aja.EnumHelper do
  @moduledoc false

  import Aja.OrdMap, only: [is_dense: 1]

  alias Aja.Vector.Raw, as: RawVector

  @dialyzer :no_opaque

  @compile {:inline, try_get_raw_vec_or_list: 1}
  def try_get_raw_vec_or_list(%Aja.Vector{__vector__: vector}), do: vector
  def try_get_raw_vec_or_list(list) when is_list(list), do: list

  def try_get_raw_vec_or_list(%Aja.OrdMap{__ord_vector__: vector} = ord_map)
      when is_dense(ord_map),
      do: vector

  def try_get_raw_vec_or_list(%Aja.OrdMap{__ord_vector__: vector}) do
    RawVector.sparse_to_list(vector)
  end

  def try_get_raw_vec_or_list(%MapSet{} = map_set) do
    MapSet.to_list(map_set)
  end

  def try_get_raw_vec_or_list(_) do
    nil
  end

  @compile {:inline, to_raw_vec_or_list: 1}
  def to_raw_vec_or_list(enumerable) do
    case try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.to_list(enumerable)
      vec_or_list -> vec_or_list
    end
  end

  @compile {:inline, to_vec_or_list: 1}
  def to_vec_or_list(enumerable) do
    case try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.to_list(enumerable)
      list when is_list(list) -> list
      vector when is_tuple(vector) -> %Aja.Vector{__vector__: vector}
    end
  end

  @compile {:inline, to_list: 1}
  def to_list(enumerable) do
    case try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.to_list(enumerable)
      list when is_list(list) -> list
      vector -> RawVector.to_list(vector)
    end
  end

  @compile {:inline, map: 2}
  def map(enumerable, fun) when is_function(fun, 1) do
    case enumerable do
      %Aja.Vector{__vector__: vector} ->
        RawVector.map_to_list(vector, fun)

      %Aja.OrdMap{__ord_vector__: vector} = ord_map when is_dense(ord_map) ->
        RawVector.map_to_list(vector, fun)

      %Aja.OrdMap{__ord_vector__: vector} = ord_map when is_dense(ord_map) ->
        Aja.Vector.Raw.foldl(vector, [], fn
          nil, acc -> acc
          key_value, acc -> [fun.(key_value) | acc]
        end)
        |> :lists.reverse()

      %MapSet{} = map_set ->
        map_set |> MapSet.to_list() |> Enum.map(fun)

      _ ->
        Enum.map(enumerable, fun)
    end
  end

  @compile {:inline, flat_map: 2}
  def flat_map(enumerable, fun) when is_function(fun, 1) do
    case try_get_raw_vec_or_list(enumerable) do
      nil ->
        enumerable
        |> Enum.reduce([], fn value, acc -> [to_list(fun.(value)) | acc] end)
        |> unwrap_flat_map([])

      list when is_list(list) ->
        flat_map_list(list, fun)

      vector ->
        vector
        |> RawVector.map_reverse_list(fn value -> to_list(fun.(value)) end)
        |> unwrap_flat_map([])
    end
  end

  defp flat_map_list([], _fun), do: []

  defp flat_map_list([head | tail], fun) do
    case fun.(head) do
      list when is_list(list) -> list ++ flat_map_list(tail, fun)
      other -> to_list(other) ++ flat_map_list(tail, fun)
    end
  end

  defp unwrap_flat_map([], acc), do: acc

  defp unwrap_flat_map([head | tail], acc) do
    unwrap_flat_map(tail, head ++ acc)
  end
end
