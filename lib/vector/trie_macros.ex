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

  defmacro find_cond({arg_name, _, nil},
             do: [{:->, _, [[condition], returned]}, {:->, _, [_, default]}]
           ) do
    clauses =
      C.arguments()
      |> Enum.with_index()
      |> Enum.flat_map(fn {arg, i} ->
        stop_check = quote do: (unquote(arg) === nil -> unquote(default))

        cond_check =
          quote do
            unquote(C.inject_arg(condition, arg_name, arg)) ->
              unquote(C.inject_arg(returned, arg_name, arg))
          end

        if i > 0 do
          stop_check ++ cond_check
        else
          cond_check
        end
      end)

    final_clause = quote do: (true -> unquote(default))

    quote do
      cond do
        unquote(clauses ++ final_clause)
      end
    end
  end
end
