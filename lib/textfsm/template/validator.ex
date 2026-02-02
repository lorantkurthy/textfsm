defmodule TextFSM.Template.Validator do
  alias TextFSM.Template
  alias Template.{State, ValueDefinition}
  alias State.Rule

  @type result() :: :ok | {:error, String.t()}

  @spec validate(TextFSM.Template.t()) :: :ok | {:error, [String.t()]}
  def validate(%Template{states: states, value_definitions: value_definitions} = template) do
    values_defined = Template.value_names(template)
    all_rules = Enum.flat_map(states, & &1.rules)

    value_errors =
      Enum.map(value_definitions, &validate_value_definition_options/1)
      |> Enum.flat_map(fn
        :ok -> []
        {:error, msg} -> [msg]
      end)

    rule_errors =
      Enum.flat_map(
        all_rules,
        fn rule ->
          result0 = validate_rule_continue_action(rule)
          result1 = validate_rule_value_exists(values_defined, rule)
          results = [result0, result1]

          for {:error, msg} <- results, do: msg
        end
      )

    errors = value_errors ++ rule_errors

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  @spec validate_value_definition_options(ValueDefinition.t()) :: result()
  def validate_value_definition_options(%ValueDefinition{name: name, options: options}) do
    if :fillup in options and Enum.any?([:required, :list], &(&1 in options)) do
      {:error,
       "Conflicting options for value `#{name}`: Fillup is incompatible with Required or List."}
    else
      :ok
    end
  end

  @spec validate_rule_value_exists([String.t()], Rule.t()) :: result()
  def validate_rule_value_exists(values_defined, %Rule{regex_tokens: regex_tokens}) do
    values_used = for {:value_descriptor, name} <- regex_tokens, do: name

    case Enum.find(values_used, &(&1 not in values_defined)) do
      nil ->
        :ok

      undefined_value ->
        {:error, "Value `#{undefined_value}` is undefined."}
    end
  end

  @spec validate_rule_continue_action(Rule.t()) :: result()
  def validate_rule_continue_action(%Rule{
        action: %Rule.Action{line_action: :continue, next_state: next_state}
      }) do
    if is_nil(next_state) do
      :ok
    else
      {:error,
       "A rule with a Continue line action does not accept a state transition. This ensures that state machines are loop free."}
    end
  end

  def validate_rule_continue_action(_), do: :ok
end
