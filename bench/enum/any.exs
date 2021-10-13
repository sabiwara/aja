last = 1000
list = Enum.map(1..last, fn i -> i == last end)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Enum.any?/2 (list)" => fn -> Enum.any?(list) end,
  "Aja.Enum.any?/2" => fn -> Aja.Enum.any?(vector) end
})
