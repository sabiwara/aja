list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.empty?/1 (list)" => fn -> Enum.empty?(list) end,
  "Enum.empty?/1 (vector)" => fn -> Enum.empty?(vector) end,
  "A.Enum.empty?/1 (vector)" => fn -> A.Enum.empty?(vector) end
})
