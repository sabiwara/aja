# TODO bench bigger numbers
list = Enum.to_list(1..100)
# tuple = List.to_tuple(list)
array = :array.from_list(list)
vector = A.Vector.new(list)

Benchee.run(%{
  # "elem/2" => fn -> elem(tuple, 55) end,
  ":array.get/2" => fn -> :array.get(55, array) end,
  "A.Vector.at/2" => fn -> A.Vector.at(vector, 55) end,
  "List.at/2" => fn -> Enum.at(list, 55) end
})
