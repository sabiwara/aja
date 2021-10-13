list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

rem10 = fn i -> rem(i, 10) end

Benchee.run(%{
  "Aja.Enum.frequencies/1 (vector)" => fn -> Aja.Enum.frequencies(vector) end,
  "Enum.frequencies/1 (list)" => fn -> Enum.frequencies(list) end,
  "Aja.Enum.frequencies_by/2 (vector)" => fn -> Aja.Enum.frequencies_by(vector, rem10) end,
  "Enum.frequencies_by/2 (list)" => fn -> Enum.frequencies_by(list, rem10) end
})
