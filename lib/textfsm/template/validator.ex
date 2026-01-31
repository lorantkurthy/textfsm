defmodule TextFSM.Template.Validator do
  alias TextFSM.Template
  alias Template.State
  alias State.Rule

  @type result() :: :ok | {:error, String.t()}

  @spec validate(TextFSM.Template.t()) :: :ok | [{:error, String.t()}]
  def validate(%Template{states: states} = template) do
    values_defined = Template.value_names(template)
    all_rules = Enum.flat_map(states, & &1.rules)

    Enum.flat_map(
      all_rules,
      fn rule ->
        result0 = validate_rule_continue_action(rule)
        result1 = validate_rule_value_exists(values_defined, rule)
        results = [result0, result1]

        for {:error, _} = error <- results, do: error
      end
    )
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
