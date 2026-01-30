defmodule TextFSM.Template.State.Rule.Action do
  @default_line_action :next
  @default_record_action :no_record

  defstruct line_action: @default_line_action,
            record_action: @default_record_action,
            next_state: nil

  @type line_action() :: :next | :continue

  @type record_action() :: :no_record | :record | :clear | :clear_all

  @type t() :: %__MODULE__{
          line_action: line_action(),
          record_action: record_action(),
          next_state: String.t()
        }

  import NimbleParsec

  defcombinatorp(
    :line_action,
    choice([
      string("Next") |> replace(:next),
      string("Continue") |> replace(:continue)
    ])
    |> unwrap_and_tag(:line_action)
  )

  defcombinatorp(
    :record_action,
    choice([
      string("NoRecord") |> replace(:no_record),
      string("Record") |> replace(:record),
      string("Clearall") |> replace(:clear_all),
      string("Clear") |> replace(:clear)
    ])
    |> unwrap_and_tag(:record_action)
  )

  line_or_record_action = choice([parsec(:line_action), parsec(:record_action)])

  line_and_record_actions =
    concat(
      parsec(:line_action),
      concat(
        ignore(string(".")),
        parsec(:record_action)
      )
    )

  line_record_action = choice([line_and_record_actions, line_or_record_action])

  next_state =
    parsec({TextFSM.ParserHelpers, :identifier})
    |> unwrap_and_tag(:next_state)

  rule_action =
    concat(
      optional(line_record_action),
      optional(
        concat(
          ignore(string(" ")),
          next_state
        )
      )
    )

  defcombinator(:rule_action, rule_action |> post_traverse({:lift, []}))

  defp lift(rest, args, context, _position, _offset) do
    line_action = Keyword.get(args, :line_action, @default_line_action)
    record_action = Keyword.get(args, :record_action, @default_record_action)
    next_state = Keyword.get(args, :next_state)

    rule_action = %__MODULE__{
      line_action: line_action,
      record_action: record_action,
      next_state: next_state
    }

    {rest, [rule_action], context}
  end
end
