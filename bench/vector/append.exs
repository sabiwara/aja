n = 1000
m = 100
list = Enum.to_list(1..n)
vector = A.Vector.new(list)
array = :array.from_list(list)
added = Enum.to_list((n + 1)..(n + m))

Benchee.run(%{
  "A.Vector.concat/2" => fn -> A.Vector.concat(vector, added) end,
  "A.Vector.append/2 in reduce" => fn ->
    Enum.reduce(added, vector, fn val, acc -> A.Vector.append(acc, val) end)
  end,
  ":array.set/3 in reduce" => fn ->
    size = :array.size(array)

    Enum.reduce(added, {size, array}, fn val, {i, acc} ->
      {i + 1, :array.set(i, val, acc)}
    end)
  end,
  "Enum.concat/2 (lists)" => fn -> Enum.concat(list, added) end,
  "Enum.into/2 (vector)" => fn -> Enum.into(added, vector) end,
  "A.Enum.into/2 (vector)" => fn -> A.Enum.into(added, vector) end
})
