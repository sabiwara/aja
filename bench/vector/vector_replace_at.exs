list = Enum.to_list(1..100)
array = :array.from_list(list)
vector = A.Vector.new(list)

Benchee.run(%{
  ":array.set/3" => fn -> :array.set(55, :foo, array) end,
  "A.Vector.replace_at/3" => fn -> A.Vector.replace_at(vector, 55, :foo) end
})
