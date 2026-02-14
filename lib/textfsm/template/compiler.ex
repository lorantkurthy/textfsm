defmodule TextFSM.Template.Compiler do
  @moduledoc """
  Compiles a parsed TextFSM template.

  The compilation process involves:
  1.  Inlining value descriptors to their regex patterns in the rules of each state.
  2.  Compiling the final string regular expressions into `Regex` structs.
  """
  alias TextFSM.Template
  alias Template.State
  alias State.Rule

  @doc """
  Compiles the given template.

  ## Parameters

  * `template` - A `TextFSM.Template` struct.
  * `modifiers` - Regex modifiers, see `Regex` module.

  ## Returns

  * `TextFSM.Template` - A compiled template struct.
  """
  @spec compile(Template.t(), String.t()) :: Template.t()
  def compile(
        %Template{value_definitions: value_definitions, states: states} = template,
        modifiers \\ ""
      ) do
    value_to_regex = Map.new(value_definitions, &{&1.name, &1.regex})
    compiled_states = Enum.map(states, &compile_state(value_to_regex, &1, modifiers))

    %{template | states: compiled_states}
  end

  defp compile_state(value_to_regex, %State{rules: rules} = state, modifiers) do
    compiled_rules = Enum.map(rules, &compile_rule(value_to_regex, &1, modifiers))
    %{state | rules: compiled_rules}
  end

  defp compile_rule(
         value_to_regex,
         %Rule{
           regex_tokens: regex_tokens
         } = rule,
         modifiers
       ) do
    inlined_regex_tokens =
      Enum.map(
        regex_tokens,
        fn
          {:value_descriptor, value_name} ->
            value_regex_str = value_to_regex[value_name]
            "(?<#{value_name}>#{value_regex_str})"

          "$$" ->
            ?$

          other ->
            other
        end
      )

    regex_str = List.to_string(inlined_regex_tokens)

    %{rule | compiled_regex: Regex.compile!(regex_str, modifiers)}
  end
end
