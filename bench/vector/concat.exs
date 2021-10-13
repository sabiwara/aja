import Aja

small_list = Enum.to_list(1..100)
big_list = Enum.to_list(1..1000)
small_vector = Aja.Vector.new(small_list)
big_vector = Aja.Vector.new(big_list)

Benchee.run(
  %{
    "big_vector +++ small_list" => fn ->
      big_vector +++ small_list
    end,
    "big_vector +++ small_vector" => fn ->
      big_vector +++ small_vector
    end,
    "small_vector +++ big_vector" => fn ->
      small_vector +++ big_vector
    end,
    "small_list ++ big_list" => fn -> small_list ++ big_list end,
    "big_list ++ small_list" => fn -> big_list ++ small_list end
  },
  memory_time: 2
)
