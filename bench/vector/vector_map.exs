# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = A.Vector.new(list)
raw = A.Vector.Raw.new(list)

Benchee.run(%{
  ":array.map/2" => fn -> :array.map(fn _, i -> i + 1 end, array) end,
  "A.Vector.map/2" => fn -> A.Vector.map(vector, &(&1 + 1)) end,
  "A.Vector.Raw.map/2" => fn -> A.Vector.Raw.map(raw, &(&1 + 1)) end,
  "Enum.map/2" => fn -> Enum.map(list, &(&1 + 1)) end
})
