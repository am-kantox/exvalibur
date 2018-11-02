defmodule ExvaliburTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Exvalibur

  import StreamData

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
end
