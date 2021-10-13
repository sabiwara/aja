# TODO bench bigger numbers
list = Enum.to_list(1..100)
# tuple = List.to_tuple(list)
array = :array.from_list(list)
vector = Aja.Vector.new(list)

Benchee.run(%{
  ":array.get/2" => fn -> :array.get(55, array) end,
  "Aja.Vector.at/2" => fn -> Aja.Vector.at(vector, 55) end,
  "Access (vector)" => fn -> vector[55] end,
  "List.at/2" => fn -> Enum.at(list, 55) end
})
