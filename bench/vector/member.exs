last = 1000
list = Enum.to_list(1..last)
vector = Aja.Vector.new(list)
search = last

Benchee.run(%{
  "Enum.member?/2 (vector)" => fn -> Enum.member?(vector, search) end,
  "Aja.Vector.Raw.member?/2" => fn -> Aja.Vector.Raw.member?(vector.__vector__, search) end,
  "Enum.member?/2 (list)" => fn -> Enum.member?(list, search) end,
  ":lists.member/2 (list)" => fn -> :lists.member(search, list) end
})
