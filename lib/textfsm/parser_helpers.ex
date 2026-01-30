defmodule TextFSM.ParserHelpers do
  import NimbleParsec

  defcombinator(
    :state_name,
    concat(
      ascii_string([?A..?Z], min: 1),
      ascii_string([?A..?Z, ?a..?z, ?0..?9], min: 0)
    )
    |> reduce({Enum, :join, []})
  )

  # Printable ASCII range without characters `\` and `"`
  normal_char =
    ascii_char([32..33, 35..91, 93..126])

  defcombinator(
    :escaped_string,
    repeat(
      choice([
        string("\\\""),
        string("\\\\"),
        normal_char
      ])
    )
    |> reduce({List, :to_string, []})
  )
end
