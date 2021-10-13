list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Enum.empty?/1 (list)" => fn -> Enum.empty?(list) end,
  "Enum.empty?/1 (vector)" => fn -> Enum.empty?(vector) end,
  "Aja.Enum.empty?/1 (vector)" => fn -> Aja.Enum.empty?(vector) end
})
