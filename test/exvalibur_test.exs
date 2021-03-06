defmodule ExvaliburTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Exvalibur
  doctest Exvalibur.Sigils

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

  test "empty rules allow everything", ctx do
    rules = []

    Exvalibur.validator!(rules, module_name: TestValidatorEmpty)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorEmpty.validate(item) == {:ok, %{foo: item.foo, num: item.num}}
    end
  end

  test "empty rules preserve previous rules", ctx do
    rules = [%{matches: %{foo: "bar"}}]
    Exvalibur.validator!(rules, module_name: TestValidatorEmptied)
    Exvalibur.validator!([], module_name: TestValidatorEmptied)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorEmptied.validate(item) ==
               if(item.foo == "bar", do: {:ok, %{foo: "bar"}}, else: :error)
    end
  end

  test "rules with matches only", ctx do
    rules = [%{matches: %{foo: "bar"}}]

    Exvalibur.validator!(rules, module_name: TestValidatorMO)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorMO.validate(item) ==
               if(item.foo == "bar", do: {:ok, %{foo: "bar"}}, else: :error)
    end
  end

  test "rules with condiitons only", ctx do
    rules = [%{conditions: %{num: %{min: 0, max: 100}}}]

    Exvalibur.validator!(rules, module_name: TestValidatorCO)

    check all item <- ctx[:data], max_runs: 100 do
      assert TestValidatorCO.validate(item) ==
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

      assert TestValidatorGMM.validate(item) == result
    end
  end

  test "Guards.Default#min/2 and Guards.Default#max/2 (binary guards)" do
    rules = [
      %{
        matches: %{foo: "bar"},
        conditions: "num >= 0 and num <= 100 and num == 42"
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidatorGMMS, merge: false)

    assert TestValidatorGMMS.validate(%{foo: "bar", num: 42, bar: 42}) ==
             {:ok, %{foo: "bar", num: 42}}

    assert TestValidatorGMMS.validate(%{foo: "bar", num: 101}) == :error
    assert TestValidatorGMMS.validate(%{foo: "zzz", num: 42}) == :error
    assert TestValidatorGMMS.validate(%{foo: 42}) == :error
  end

  ##############################################################################

  test "arbitrary guards" do
    rules = [
      %{
        matches: %{foo: "bar", num: ~Q[num]},
        guards: %{is_percent: "num >= 0 and (num <= 100 or num == 200)"}
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidatorAG, merge: false)

    assert TestValidatorAG.validate(%{foo: "bar", num: 42, bar: 42}) ==
             {:ok, %{foo: "bar", num: 42}}

    assert TestValidatorAG.validate(%{foo: "bar", num: 200, bar: 42}) ==
             {:ok, %{foo: "bar", num: 200}}

    assert TestValidatorAG.validate(%{foo: "bar", num: 101}) == :error
    assert TestValidatorAG.validate(%{foo: "zzz", num: 42}) == :error
    assert TestValidatorAG.validate(%{foo: 42}) == :error
  end

  test "arbitrary guards (as list)" do
    rules = [
      %{
        matches: %{foo: "bar", num: ~Q[num]},
        guards: ["num >= 0 and (num <= 100 or num == 200)"]
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidatorAG, merge: false)

    assert TestValidatorAG.validate(%{foo: "bar", num: 42, bar: 42}) ==
             {:ok, %{foo: "bar", num: 42}}

    assert TestValidatorAG.validate(%{foo: "bar", num: 200, bar: 42}) ==
             {:ok, %{foo: "bar", num: 200}}

    assert TestValidatorAG.validate(%{foo: "bar", num: 101}) == :error
    assert TestValidatorAG.validate(%{foo: "zzz", num: 42}) == :error
    assert TestValidatorAG.validate(%{foo: 42}) == :error
  end

  ##############################################################################
  test "rules with pattern matching" do
    rules = [%{matches: %{foo: quote(do: <<"b", _::binary>>)}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPM)

    assert TestValidatorPM.validate(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
    assert TestValidatorPM.validate(%{foo: "baz", bar: 42}) == {:ok, %{foo: "baz"}}
    assert TestValidatorPM.validate(%{foo: "zzz"}) == :error
    assert TestValidatorPM.validate(%{foo: 42}) == :error
  end

  test "rules with pattern matching (sigil)" do
    rules = [%{matches: %{foo: ~Q[<<"b", _::binary>>]}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPMS)

    assert TestValidatorPMS.validate(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
    assert TestValidatorPMS.validate(%{foo: "baz", bar: 42}) == {:ok, %{foo: "baz"}}
    assert TestValidatorPMS.validate(%{foo: "zzz"}) == :error
    assert TestValidatorPMS.validate(%{foo: 42}) == :error
  end

  test "rules with pattern matching (complicated)" do
    rules = [%{matches: %{foo: ~Q[%{} = _]}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPMCS)

    assert TestValidatorPMCS.validate(%{foo: %{bar: "baz"}}) == {:ok, %{foo: %{bar: "baz"}}}
    assert TestValidatorPMCS.validate(%{foo: "zzz"}) == :error
  end

  test "rules with pattern matching (interpolated sigil)" do
    letter = "b"
    rules = [%{matches: %{foo: ~q[<<"#{letter}", _::binary>>]}}]

    Exvalibur.validator!(rules, module_name: TestValidatorPMIS)

    assert TestValidatorPMIS.validate(%{foo: "bar"}) == {:ok, %{foo: "bar"}}
    assert TestValidatorPMIS.validate(%{foo: "baz", bar: 42}) == {:ok, %{foo: "baz"}}
    assert TestValidatorPMIS.validate(%{foo: "zzz"}) == :error
    assert TestValidatorPMIS.validate(%{foo: 42}) == :error
  end

  test "rules are stored in the generated module" do
    rules = [
      %{
        matches: %{num: ~Q[num]},
        conditions: %{foo: %{min: 0, max: 100}},
        guards: %{is_percent: "num >= 0 and (num <= 100 or num == 200)"}
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidatorFULL, merge: false)
    assert TestValidatorFULL.rules() == rules
  end

  # prints out a deprecation warning
  test "deprecated valid?/1" do
    assert TestValidatorDeprecation.valid?(%{foo: 42}) == {:ok, %{foo: 42}}
  end

  test "bad sigil" do
    # This will result in compile-time error, so no way to assert properly
    # assert_raise TokenMissingError, ~s|missing terminator: "|, ~Q[<<"b, _::binary>>]
  end
end
