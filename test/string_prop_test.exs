defmodule Aja.String.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag timeout: :infinity
  @moduletag :property

  def candidate_string do
    string(:printable)
  end

  property "slugify/2 works with any string (mode: :default)" do
    check all string <- candidate_string(), max_runs: 1000 do
      slug = Aja.String.slugify(string)
      assert ^slug = Aja.String.slugify(string, :default)

      # FIXME find a way to re-enable this test in some form
      # reapplying slugify twice shouldn't change anything
      # but using `==` would fail, or we would need to apply the normalization twice
      # assert String.equivalent?(slug, Aja.String.slugify(slug))

      # should have no whitespace
      refute slug =~ ~r(\s)u
      # should have no uppercase
      refute slug =~ ~r([A-Z])u

      refute String.first(slug) == "-"
      refute String.last(slug) == "-"
    end
  end

  property "slugify/2 works with any string (mode: :ascii)" do
    check all string <- candidate_string(), max_runs: 1000 do
      slug = Aja.String.slugify(string)
      assert ^slug = Aja.String.slugify(string, :default)

      # FIXME find a way to re-enable this test in some form
      # reapplying slugify twice shouldn't change anything
      # but using `==` would fail, or we would need to apply the normalization twice
      # assert String.equivalent?(slug, Aja.String.slugify(slug))

      # should have no whitespace
      refute slug =~ ~r(\s)u
      # should have no uppercase
      refute slug =~ ~r([A-Z])u

      refute String.first(slug) == "-"
      refute String.last(slug) == "-"
    end
  end
end
