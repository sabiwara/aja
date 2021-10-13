defmodule Aja.String do
  @moduledoc ~S"""
  Some extra helper functions for working with strings,
  that are not in the core `String` module.
  """

  @type mode :: :default | :ascii | :greek
  @modes [:default, :ascii, :greek]

  @doc ~S"""
  Transforms the text as a slug. Removes whitespace, special characters and
  converts the rest to lowercase.

  This is typically useful to generate URLs based on content, e.g. the title of an article.

  Like `String.downcase/2`, `slugify/2` also can handle the following modes:
  `:default` (keeps unicode), `:ascii` or `:greek`.

  ## Examples

      iex> Aja.String.slugify("> \"It Was Me, Dio!!!\"\n")
      "it-was-me-dio"
      iex> Aja.String.slugify("Joseph Joestar a.k.a ジョジョ")
      "joseph-joestar-aka-ジョジョ"
      iex> Aja.String.slugify(<<220>>)
      ** (ArgumentError) Invalid string <<220>>

  `:ascii` converts to ascii when possible or strips characters:

      iex> Aja.String.slugify("OLÁ!\n", :ascii)
      "ola"
      iex> Aja.String.slugify("DIOの世界 -さらば友よ- ", :ascii)
      "dio"

  `:greek` handles the context sensitive sigma in Greek:

      iex> Aja.String.slugify("\tΣΣ?")
      "σσ"
      iex> Aja.String.slugify("\tΣΣ?", :greek)
      "σς"

  """
  @spec slugify(String.t(), mode) :: String.t()
  def slugify(string, mode \\ :default) when is_binary(string) and mode in @modes do
    string
    |> normalize(mode)
    |> String.downcase(mode)
    |> try_replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[-\s]+/u, "-")
    |> String.replace(~r/^(-|_)+/u, "")
    |> String.replace(~r/(-|_)+$/u, "")
  end

  defp normalize(string, :ascii) do
    for <<c <- nfkd_normalize(string)>>, c in 0..127, into: "", do: <<c>>
  end

  defp normalize(string, _mode) do
    nfkc_normalize(string)
  end

  defp nfkc_normalize(string) do
    # Note: same implementation as `String.normalize(string, :nfkc)` in Elixir 1.11
    # TODO replace when removing support for 1.10
    case :unicode.characters_to_nfkc_binary(string) do
      normalized when is_binary(normalized) -> normalized
      {:error, good, <<head, rest::binary>>} -> good <> <<head>> <> nfkc_normalize(rest)
    end
  end

  defp nfkd_normalize(string) do
    # Note: same implementation as `String.normalize(string, :nfkd)` in Elixir 1.11
    # TODO replace when removing support for 1.10
    case :unicode.characters_to_nfkd_binary(string) do
      normalized when is_binary(normalized) -> normalized
      {:error, good, <<head, rest::binary>>} -> good <> <<head>> <> nfkd_normalize(rest)
    end
  end

  defp try_replace(string, regex, new) do
    try do
      String.replace(string, regex, new)
    rescue
      ArgumentError ->
        raise ArgumentError, "Invalid string #{inspect(string)}"
    end
  end
end
