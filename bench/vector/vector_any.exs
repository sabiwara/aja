last = 1000
list = Enum.map(1..last, fn i -> i == last end)
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.any?/2 (list)" => fn -> Enum.any?(list) end,
  "A.Vector.any?/2" => fn -> A.Vector.any?(vector) end
})
