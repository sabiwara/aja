# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = Aja.Vector.new(list)

Benchee.run(%{
  ":array.map/2 (array)" => fn -> :array.map(fn _, i -> i + 1 end, array) end,
  "Aja.Vector.map/2 (vector)" => fn -> Aja.Vector.map(vector, &(&1 + 1)) end,
  "Aja.Enum.map/2 (vector)" => fn -> Aja.Enum.map(vector, &(&1 + 1)) end,
  "Enum.map/2 (list)" => fn -> Enum.map(list, &(&1 + 1)) end
})
