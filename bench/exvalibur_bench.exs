defmodule Exvalibur.Bench do
  use Benchfella
  import Exvalibur.Sigils

  setup_all do
    rules = [
      %{
        matches: %{foo: "bar", num: ~Q[num]},
        guards: ["num >= 0 and (num <= 100 or num == 200)"]
      }
    ]

    {:ok, Exvalibur.validator!(rules, module_name: PersistentValidator, merge: false)}
  end

  teardown_all mod do
  end

  defp explicit_checker(map) do
    map[:foo] == "bar" and (map[:num] >= 0 and (map[:num] <= 100 or map[:num] == 200))
  end

  bench "Exvalibur.validator!/3" do
    rules = [
      %{
        matches: %{foo: "bar", num: ~Q[num]},
        guards: ["num >= 0 and (num <= 100 or num == 200)"]
      }
    ]

    Exvalibur.validator!(rules, module_name: TestValidator, merge: false)
  end

  bench "PersistentValidator.valid?" do
    PersistentValidator.valid?(%{foo: "bar", num: 42, bar: 42})
  end

  bench "explicit_checker/1" do
    explicit_checker(%{foo: "bar", num: 42, bar: 42})
  end
end
