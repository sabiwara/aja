list = Enum.to_list(1..100)
vector = A.Vector.new(list)

rem10 = fn i -> rem(i, 10) end

Benchee.run(%{
  "A.Enum.group_by/2 (vector)" => fn -> A.Enum.group_by(vector, rem10) end,
  "Enum.group_by/2  (vector)" => fn -> Enum.group_by(vector, rem10) end,
  "Enum.group_by/2 (list)" => fn -> Enum.group_by(list, rem10) end
})
