defmodule ExvaliburTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Exvalibur

  import StreamData
  import Exvalibur.Sigils

  setup_all do
    [
      data:
        fixed_map(%{
          foo: one_of([constant("bar"), binary()]),
          num: integer()
        })
    ]
  end

  test "rules with matches only", ctx do
    rules = [%{matches: %{foo: "bar"}}]

    Exvalibur.validator!(rules, module_name: TestValidatorMO)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorMO.valid?(item) ==
               if(item.foo == "bar", do: {:ok, %{foo: "bar"}}, else: :error)
    end
  end

  test "rules with condiitons only", ctx do
    rules = [%{conditions: %{num: %{min: 0, max: 100}}}]

    Exvalibur.validator!(rules, module_name: TestValidatorCO)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorCO.valid?(item) ==
               if(item.num >= 0 and item.num <= 100, do: {:ok, %{num: item.num}}, else: :error)
    end
  end

  ##############################################################################

  test "Guards.Default#min/2 and Guards.Default#max/2", ctx do
    rules = [
      %{
        matches: %{foo: "bar"},
        conditions: %{num: %{min: 0, max: 100}}
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidatorGMM, merge: false)

    check all item <- ctx[:data], max_runs: 100 do
      result =
        case({item.foo, item.num}) do
          {"bar", num} when num >= 0 and num <= 100 ->
            {:ok, item}

          _ ->
            :error
        end

      assert TestValidatorGMM.valid?(item) == result
    end
  end

  ##############################################################################

  test "rules with pattern matching" do
    rules = [%{matches: %{foo: quote(do: <<"b", _::binary>>)}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPM)

    assert TestValidatorPM.valid?(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
    assert TestValidatorPM.valid?(%{foo: "baz", bar: 42}) == {:ok, %{foo: "baz"}}
    assert TestValidatorPM.valid?(%{foo: "zzz"}) == :error
    assert TestValidatorPM.valid?(%{foo: 42}) == :error
  end

  test "rules with pattern matching (sigil)" do
    rules = [%{matches: %{foo: ~V[<<"b", _::binary>>]}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPMS)

    assert TestValidatorPMS.valid?(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
    assert TestValidatorPMS.valid?(%{foo: "baz", bar: 42}) == {:ok, %{foo: "baz"}}
    assert TestValidatorPMS.valid?(%{foo: "zzz"}) == :error
    assert TestValidatorPMS.valid?(%{foo: 42}) == :error
  end

  test "bad sigil" do
    # This will result in compile-time error, so no way to assert properly
    # assert_raise TokenMissingError, ~s|missing terminator: "|, ~V[<<"b, _::binary>>]
  end
end
