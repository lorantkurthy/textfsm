defmodule TextFSM.ParserHelpers do
  import NimbleParsec

  defcombinator(
    :whitespace,
    ignore(string(" "))
  )

  defcombinator(
    :newlines,
    times(parsec(:newline), min: 1)
  )

  defcombinator(
    :newline,
    ignore(string("\n"))
  )

  defcombinator(
    :identifier,
    concat(
      ascii_string([?A..?Z], min: 1),
      ascii_string([?A..?Z, ?a..?z, ?0..?9, ?_..?_], min: 0)
    )
    |> reduce({Enum, :join, []})
  )

  # Printable Unicode range without the character `$`
  defcombinator(
    :rule_regex_char,
    utf8_char([0x20..0x23, 0x25..0x7E, 0xA0..0xD7FF, 0xE000..0xFFFD, 0x10000..0x10FFFF])
  )

  # Printable Unicode range
  defcombinator(
    :regex_char,
    utf8_char([0x20..0x7E, 0xA0..0xD7FF, 0xE000..0xFFFD, 0x10000..0x10FFFF])
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
