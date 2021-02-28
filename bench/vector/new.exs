list = Enum.to_list(1..100)

Benchee.run(%{
  ":array.from_list/1" => fn -> :array.from_list(list) end,
  "A.Vector.new/1" => fn -> A.Vector.new(list) end
})
