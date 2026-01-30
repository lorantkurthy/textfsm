defmodule TextFSM.Template.State.Rule.ErrorAction do
  @enforce_keys [:message]
  defstruct [:message]

  @type t() :: %__MODULE__{
          message: String.t()
        }

  import NimbleParsec

  defcombinator(
    :error_action,
    concat(
      ignore(string("Error \"")),
      concat(
        parsec({TextFSM.ParserHelpers, :escaped_string}),
        ignore(string("\""))
      )
    )
    |> unwrap_and_tag(:error_message)
    |> post_traverse({:lift, []})
  )

  defp lift(rest, args, context, _position, _offset) do
    message = Keyword.get(args, :error_message)

    {rest, [%__MODULE__{message: message}], context}
  end
end
