defmodule TextFSM do
  @moduledoc """
  TextFSM is a template-based state machine for parsing semi-structured text.

  This is an Elixir implementation of the [TextFSM](https://github.com/google/textfsm) library written in Python.
  TextFSM allows you to define a template that describes the structure of your text (e.g. CLI output from network devices)
  and parse it into a structured table.

  ## Example

      template = \"\"\"
      Value INTERFACE (\\\\S+)
      Value IP_ADDRESS (\\\\d+\\\.\\\\d+\\\.\\\\d+\\\.\\\\d+|unassigned)
      Value STATUS (up|down|administratively down)
      Value PROTOCOL (up|down)

      Start
        ^${INTERFACE}\\\\s+${IP_ADDRESS}\\\\s+\\\\w+\\\\s+\\\\w+\\\\s+${STATUS}\\\\s+${PROTOCOL} -> Record
      \"\"\"

      text = \"\"\"
      Interface              IP-Address      OK? Method Status                Protocol
      GigabitEthernet0/0     192.168.1.1     YES NVRAM  up                    up
      GigabitEthernet0/1     unassigned      YES NVRAM  administratively down down
      GigabitEthernet0/2     10.0.0.5        YES manual up                    up
      Loopback0              127.0.0.1       YES unset  up                    up
      \"\"\"

      {:ok, result} = TextFSM.parse(template, text)


    Result:

      %{
        "INTERFACE" => ["GigabitEthernet0/0", "GigabitEthernet0/1",
        "GigabitEthernet0/2", "Loopback0"],
        "IP_ADDRESS" => ["192.168.1.1", "unassigned", "10.0.0.5", "127.0.0.1"],
        "PROTOCOL" => ["up", "down", "up", "up"],
        "STATUS" => ["up", "administratively down", "up", "up"]
      }

  """
  alias __MODULE__.{Template, Engine}

  @type byte_offset() :: non_neg_integer()

  @type line() :: {pos_integer(), byte_offset}

  @type rest() :: binary()

  @type reason() :: String.t()

  @type context() :: map()

  @type parse_error() :: {:error, reason(), rest(), context(), line(), byte_offset()}

  @type validation_message() :: {:error, String.t()} | {:warning, String.t()}

  @type value_name() :: String.t()

  @type value() :: nil | String.t() | [String.t()]

  @type table() :: %{value_name() => [value()]}

  @doc """
  Parses and compiles a TextFSM template string.

  This function takes the raw template string, parses it into its internal representation,
  validates the structure, and compiles the regular expressions for execution.

  ## Parameters

  * `template` - A string containing the TextFSM template definition.
  * `modifiers` - Regex modifiers, see `Regex` module.

  ## Returns

  * `{:ok, template}`
  * `{:error, reason, rest, context, line, byte_offset}` - If the template syntax is invalid.
  * `{:error, [messages]}` - If the template fails validation.
  """
  @spec parse_template(binary(), String.t()) ::
          {:ok, Template.t()} | parse_error() | [validation_message()]
  def parse_template(template, modifiers \\ "") do
    with {:ok, [template], _, _, _, _} <- Template.template(template),
         :ok <- Template.Validator.validate(template) do
      {:ok, template |> Template.Compiler.compile(modifiers)}
    else
      {:error, reason, rest, context, line, byte_offset} ->
        {:error, reason, rest, context, line, byte_offset}

      validation_messages ->
        validation_messages
    end
  end

  @doc """
  Parses text using the provided TextFSM template.

  ## Parameters

  * `template` - A string containing the TextFSM template.
  * `text` - The input text to be parsed.
  * `modifiers` - Regex modifiers, see `Regex` module.

  ## Returns

  * `{:ok, table}` - A column-oriented table represented as a map from value names to columns.
  * `{:error, ...}` - If parsing of the TextFSM template fails. See `parse_template/1` for more details.
  """
  @spec parse(binary(), binary(), String.t()) ::
          {:ok, table()} | parse_error() | [validation_message()]
  def parse(template, text, modifiers \\ "") do
    with {:ok, template} <- parse_template(template, modifiers),
         engine = Engine.new(template, text) do
      {:ok, Engine.run(engine)}
    else
      errors -> errors
    end
  end
end
