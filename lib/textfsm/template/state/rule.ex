defmodule TextFSM.Template.State.Rule do
  @enforce_keys [:regex_tokens]
  defstruct [:regex_tokens, :compiled_regex, :action]

  alias __MODULE__.{Action, ErrorAction}
  import NimbleParsec

  @type value_descriptor() :: {:value_descriptor, String.t()}

  @type regex_token() ::
          char()
          | value_descriptor()

  @type t() :: %__MODULE__{
          regex_tokens: [],
          compiled_regex: Regex.t(),
          action: Action.t() | ErrorAction.t()
        }

  value_descriptor =
    concat(
      ignore(string("${")),
      concat(
        parsec({TextFSM.ParserHelpers, :identifier}),
        ignore(string("}"))
      )
    )
    |> unwrap_and_tag(:value_descriptor)

  # Printable ASCII range without the `$` character
  rule_regex_char =
    ascii_char([32..35, 37..126])

  defcombinatorp(
    :rule_regex_atom,
    choice([
      string("$$"),
      value_descriptor,
      rule_regex_char
    ])
  )

  defcombinatorp(
    :rule_action,
    concat(
      ignore(string(" -> ")),
      choice([
        parsec({ErrorAction, :error_action}),
        parsec({Action, :rule_action})
      ])
    )
  )

  rule_regex =
    repeat(lookahead_not(parsec(:rule_action)) |> parsec(:rule_regex_atom))

  defcombinator(
    :rule,
    concat(
      ignore(string("^")),
      concat(
        rule_regex |> tag(:regex_tokens),
        optional(parsec(:rule_action)) |> tag(:action)
      )
    )
    |> post_traverse({:lift, []})
  )

  defp lift(rest, args, context, _position, _offset) do
    regex_tokens = Keyword.get(args, :regex_tokens)

    action =
      case Keyword.get(args, :action) do
        [action] -> action
        _ -> %Action{}
      end

    rule = %__MODULE__{
      regex_tokens: [?^ | regex_tokens],
      action: action
    }

    {rest, [rule], context}
  end
end
