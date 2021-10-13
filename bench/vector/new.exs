list = Enum.to_list(1..100)

Benchee.run(%{
  ":array.from_list/1" => fn -> :array.from_list(list) end,
  "Aja.Vector.new/1" => fn -> Aja.Vector.new(list) end
})
