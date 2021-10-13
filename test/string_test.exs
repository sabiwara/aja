defmodule Aja.StringTest do
  use ExUnit.Case, async: true

  doctest Aja.String

  test "slugify/2 (mode: :default)" do
    expected = %{
      " \n ab.12 \t, " => "ab12",
      "-The World-" => "the-world",
      "email: foo@bar.baz" => "email-foobarbaz",
      "-__MODULE__" => "module",
      "-_-_-_-_-_-" => "",
      "__underscores__inside___" => "underscores__inside",
      "　OLÁ! " => "olá",
      "　ゴゴゴ... " => "ゴゴゴ",
      "　DIOの世界 -さらば友よ- " => "dioの世界-さらば友よ"
    }

    actual =
      Map.new(expected, fn {key, _value} ->
        {key, Aja.String.slugify(key)}
      end)

    assert actual == expected
  end

  test "slugify/2 (mode: :ascii)" do
    expected = %{
      " \n ab.12 \t, " => "ab12",
      "-The World-" => "the-world",
      "email: foo@bar.baz" => "email-foobarbaz",
      "-__MODULE__" => "module",
      "-_-_-_-_-_-" => "",
      "__underscores__inside___" => "underscores__inside",
      "　OLÁ! " => "ola",
      "　ゴゴゴ... " => "",
      "　DIOの世界 -さらば友よ- " => "dio"
    }

    actual =
      Map.new(expected, fn {key, _value} ->
        {key, Aja.String.slugify(key, :ascii)}
      end)

    assert actual == expected
  end

  test "slugif/2 (mode: :greek)" do
    assert "σσ" = Aja.String.slugify("\tΣΣ?")
    assert "σς" = Aja.String.slugify("\tΣΣ?", :greek)
  end
end
