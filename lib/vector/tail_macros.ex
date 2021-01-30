defmodule A.Vector.Tail.Macros do
  @moduledoc false

  alias A.Vector.CodeGen, as: C
  require C

  defmacro find_cond({arg_name, _, nil}, size,
             do: [{:->, _, [[condition], returned]}, {:->, _, [_, default]}]
           ) do
    clauses =
      C.arguments()
      |> Enum.with_index()
      |> Enum.flat_map(fn {arg, i} ->
        stop_check = quote do: (unquote(i) === unquote(size) -> unquote(default))

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
