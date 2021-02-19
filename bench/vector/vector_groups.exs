list = Enum.to_list(1..100)
vector = A.Vector.new(list)

rem10 = fn i -> rem(i, 10) end

Benchee.run(%{
  "A.Vector.frequencies/1" => fn -> A.Vector.frequencies(vector) end,
  "Enum.frequencies/1 (list)" => fn -> Enum.frequencies(list) end,
  "A.Vector.frequencies_by/2" => fn -> A.Vector.frequencies_by(vector, rem10) end,
  "Enum.frequencies_by/2 (list)" => fn -> Enum.frequencies_by(list, rem10) end,
  "A.Vector.group_by/2" => fn -> A.Vector.group_by(vector, rem10) end,
  "Enum.group_by/2 (list)" => fn -> Enum.group_by(list, rem10) end
})
