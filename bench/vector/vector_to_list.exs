# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = A.Vector.new(list)
raw = A.Vector.Raw.new(list)

Benchee.run(%{
  ":array.to_list/1" => fn -> :array.to_list(array) end,
  "A.Vector.to_list/1" => fn -> A.Vector.to_list(vector) end,
  "A.Vector.Raw.to_list/1" => fn -> A.Vector.Raw.to_list(raw) end,
  "Enum.to_list/1" => fn -> Enum.to_list(vector) end
})
