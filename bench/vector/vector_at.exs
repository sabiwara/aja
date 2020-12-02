# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = A.Vector.new(list)
raw = A.Vector.Raw.new(list)

Benchee.run(%{
  ":array.get/2" => fn -> :array.get(55, array) end,
  "A.Vector.at/2" => fn -> A.Vector.at(vector, 55) end,
  "A.Vector.Raw.fetch/2" => fn -> A.Vector.Raw.fetch_positive(raw, 55) end,
  "List.at/2" => fn -> Enum.at(list, 55) end
})
