defmodule Bench.IO.SigilI do
  import A

  def before_scenario(_) do
    first_names = ["John", "Jane", "Joe", "Joseph"]
    last_names = ["Doe", "Joestar", "Wood", "Black"]
    :rand.seed(:exrop, {1, 2, 3})

    Stream.repeatedly(fn ->
      {Enum.random(first_names), Enum.random(last_names)}
    end)
    |> Enum.take(20)
  end

  def run() do
    Benchee.run(
      [
        {"interpolation (simple)",
         fn names ->
           for {first, last} <- names do
             "#{first} #{last}"
           end
         end},
        {"~i sigil (simple)",
         fn names ->
           for {first, last} <- names do
             ~i"#{first} #{last}"
           end
         end},
        {"interpolation (nested)",
         fn names ->
           for {first, last} <- names do
             fullname = "#{first} #{last}"
             "Hello, #{fullname}!"
           end
         end},
        {"~i sigil (nested)",
         fn names ->
           for {first, last} <- names do
             fullname = ~i"#{first} #{last}"
             ~i"Hello, #{fullname}!"
           end
         end}
      ],
      before_scenario: &before_scenario/1
    )
  end
end

Bench.IO.SigilI.run()
