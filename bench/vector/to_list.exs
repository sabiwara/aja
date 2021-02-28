# TODO bench bigger numbers
list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = A.Vector.new(list)

Benchee.run(%{
  ":array.to_list/1 (array)" => fn -> :array.to_list(array) end,
  "A.Vector.to_list/1 (vector)" => fn -> A.Vector.to_list(vector) end,
  "A.Enum.to_list/1 (vector)" => fn -> A.Enum.to_list(vector) end,
  "Enum.to_list/1 (vector)" => fn -> Enum.to_list(vector) end
})
