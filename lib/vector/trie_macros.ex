defmodule A.Vector.Trie.Macros do
  @moduledoc false

  alias A.Vector.CodeGen, as: C
  require C

  defmacro def_foldl(header, do: body) do
    {name, args} = Macro.decompose_call(header)
    [{:trie, _, _}, {:level, _, _} = level, acc | rest_args] = args
    expanded_body = Macro.expand(body, __CALLER__)

    quote do
      def unquote(name)(unquote_splicing(args))

      def unquote(name)(unquote(C.array()), _level = 0, unquote(acc), unquote_splicing(rest_args)) do
        unquote(expanded_body)
      end

      def unquote(name)(
            unquote(C.array()),
            unquote(level),
            unquote(acc),
            unquote_splicing(rest_args)
          ) do
        child_level = C.decr_level(unquote(level))

        unquote(
          C.arguments()
          |> Enum.reduce(acc, fn arg, acc ->
            quote do
              acc = unquote(acc)

              case unquote(arg) do
                nil -> acc
                value -> unquote(name)(value, child_level, acc, unquote_splicing(rest_args))
              end
            end
          end)
        )
      end
    end
  end
end
