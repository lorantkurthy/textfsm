defmodule TextFSM.Template.Compiler do
  alias TextFSM.Template
  alias Template.State
  alias State.Rule

  def compile_template(%Template{value_definitions: value_definitions, states: states} = template) do
    value_to_regex = Map.new(value_definitions, &{&1.name, &1.regex})
    compiled_states = Enum.map(states, &compile_state(value_to_regex, &1))

    %{template | states: compiled_states}
  end

  defp compile_state(value_to_regex, %State{rules: rules} = state) do
    compiled_rules = Enum.map(rules, &compile_rule(value_to_regex, &1))
    %{state | rules: compiled_rules}
  end

  defp compile_rule(
         value_to_regex,
         %Rule{
           regex_tokens: regex_tokens
         } = rule
       ) do
    inlined_regex_tokens =
      Enum.map(
        regex_tokens,
        fn
          {:value_descriptor, value_name} ->
            value_regex_str = value_to_regex[value_name]
            "(?<#{value_name}>#{value_regex_str})"

          other ->
            other
        end
      )

    regex_str = List.to_string(inlined_regex_tokens)

    %{rule | compiled_regex: Regex.compile!(regex_str)}
  end
end
