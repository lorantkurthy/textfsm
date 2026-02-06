defmodule TextFSM.Template.Validator do
  alias TextFSM.Template
  alias Template.{State, ValueDefinition}
  alias State.Rule

  @type error_or_warning() :: {:error, String.t()} | {:warning, String.t()}

  @type result() :: :ok | [error_or_warning()]

  @spec validate(TextFSM.Template.t()) :: result()
  def validate(%Template{states: states, value_definitions: value_definitions} = template) do
    values_defined = Template.value_names(template)
    all_rules = Enum.flat_map(states, & &1.rules)

    value_errors =
      Enum.map(value_definitions, &validate_value_definition_options/1)

    rule_errors =
      Enum.flat_map(
        all_rules,
        fn rule ->
          result0 = validate_rule_continue_action(rule)
          result1 = validate_rule_value_exists(values_defined, rule)
          [result0, result1]
        end
      )

    state_errors =
      [validate_start_state_exists(states)]

    state_warnings =
      Enum.map(states, &validate_eof_state/1)

    errors_and_warnings = value_errors ++ rule_errors ++ state_errors ++ state_warnings

    case errors_and_warnings |> Enum.reject(&(&1 == :ok)) do
      [] -> :ok
      _ -> errors_and_warnings
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

  @spec validate_start_state_exists([State.t()]) :: result()
  def validate_start_state_exists(states) do
    if Enum.any?(states, &(&1.name == "Start")) do
      :ok
    else
      {:error, "Template must contain a Start state."}
    end
  end

  @spec validate_eof_state(State.t()) :: :ok | {:warning, String.t()}
  def validate_eof_state(%State{name: "EOF", rules: rules}) when length(rules) > 0 do
    {:warning, "The EOF state does not accept rules and they will be ignored."}
  end

  def validate_eof_state(_), do: :ok
end
