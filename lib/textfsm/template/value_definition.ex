defmodule TextFSM.Template.ValueDefinition do
  @moduledoc """
  Represents a Value definition in a TextFSM template.

  A Value definition line looks like:
      Value [Option,Option...] Name (Regex)

  It defines a column that will be in the resulting table.
  """
  @enforce_keys [:name, :regex]
  defstruct [:name, :options, :regex]

  @type option() :: :filldown | :key | :required | :list | :fillup

  @type t() :: %__MODULE__{
          name: String.t(),
          options: [option()],
          regex: String.t()
        }

  import NimbleParsec

  whitespace = parsec({TextFSM.ParserHelpers, :whitespace})

  newline = parsec({TextFSM.ParserHelpers, :newline})

  value_name = parsec({TextFSM.ParserHelpers, :identifier})

  defcombinatorp(
    :value_option,
    choice([
      string("Filldown") |> replace(:filldown),
      string("Key") |> replace(:key),
      string("Required") |> replace(:required),
      string("List") |> replace(:list),
      string("Fillup") |> replace(:fillup)
    ])
  )

  value_options =
    concat(
      parsec(:value_option),
      repeat(
        concat(
          ignore(string(",")),
          parsec(:value_option)
        )
      )
    )

  value_regex =
    concat(
      ignore(string("(")),
      concat(
        repeat(
          lookahead_not(concat(string(")"), choice([eos(), newline])))
          |> parsec({TextFSM.ParserHelpers, :regex_char})
        ),
        ignore(string(")"))
      )
    )

  defparsec(
    :value_definition,
    concat(
      ignore(string("Value ")),
      concat(
        optional(concat(value_options, whitespace))
        |> tag(:options),
        concat(
          value_name |> unwrap_and_tag(:name),
          concat(
            whitespace,
            value_regex |> tag(:regex_tokens)
          )
        )
      )
    )
    |> post_traverse({:lift, []}),
    export_combinator: true
  )

  defp lift(rest, args, context, _position, _offset) do
    name = Keyword.get(args, :name)
    options = Keyword.get(args, :options)
    regex_tokens = Keyword.get(args, :regex_tokens)

    value_definition = %__MODULE__{
      name: name,
      options: options,
      regex: regex_tokens |> List.to_string()
    }

    {rest, [value_definition], context}
  end
end
