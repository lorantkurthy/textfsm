defmodule TextFSM.Parser.ValueDefinitionTest do
  use ExUnit.Case

  alias TextFSM.Template.ValueDefinition
  import ValueDefinition

  @options ["Filldown", "Key", "Required", "List", "Fillup"]
  @options_atoms [:filldown, :key, :required, :list, :fillup]
  @date_regex "^[a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

  describe "value_definition/1" do
    test "without any options" do
      text = "Value Date (#{@date_regex})"

      assert_value_definition(text, "Date", [], @date_regex)
    end

    test "with a single option" do
      for {option, option_atom} <- Enum.zip(@options, @options_atoms) do
        assert_value_definition(
          "Value #{option} Date (#{@date_regex})",
          "Date",
          [option_atom],
          @date_regex
        )
      end
    end

    test "with multiple options" do
      assert_value_definition(
        "Value Filldown,Key Date (#{@date_regex})",
        "Date",
        [:filldown, :key],
        @date_regex
      )

      assert_value_definition(
        "Value Required,List,Fillup Date (#{@date_regex})",
        "Date",
        [:required, :list, :fillup],
        @date_regex
      )

      assert_value_definition(
        "Value Filldown,Key,Required,List,Fillup Date (#{@date_regex})",
        "Date",
        [:filldown, :key, :required, :list, :fillup],
        @date_regex
      )

      assert_value_definition(
        "Value Key,Filldown Date (#{@date_regex})",
        "Date",
        [:key, :filldown],
        @date_regex
      )
    end
  end

  defp assert_value_definition(text, expected_name, expected_options, expected_regex) do
    assert {:ok, parsed, rest, _context, _line, _byte_offset} = value_definition(text)
    assert rest == ""

    assert [
             %ValueDefinition{
               name: ^expected_name,
               options: ^expected_options,
               regex: ^expected_regex
             }
           ] = parsed
  end
end
