# TextFSM

[![Hex Version](https://img.shields.io/hexpm/v/textfsm.svg)](https://hex.pm/packages/textfsm) [![Hex Docs](https://img.shields.io/badge/hex-docs-green.svg)](https://hexdocs.pm/textfsm/)

TextFSM is a template-based state machine designed to parse semi-structured text (such as CLI output) into structured data.

This is an Elixir implementation of the original [TextFSM](https://github.com/google/textfsm) written in Python.

This implementation uses [NimbleParsec](https://github.com/dashbitco/nimble_parsec) to parse templates.

## Demonstration

Given the template:

```
Value INTERFACE (\S+)
Value IP_ADDRESS (\d+\.\d+\.\d+\.\d+|unassigned)
Value STATUS (up|down|administratively down)
Value PROTOCOL (up|down)

Start
  ^${INTERFACE}\s+${IP_ADDRESS}\s+\w+\s+\w+\s+${STATUS}\s+${PROTOCOL} -> Record
```

and the input text:

```
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet0/0     192.168.1.1     YES NVRAM  up                    up      
GigabitEthernet0/1     unassigned      YES NVRAM  administratively down down    
GigabitEthernet0/2     10.0.0.5        YES manual up                    up      
Loopback0              127.0.0.1       YES unset  up                    up
```

calling `TextFSM.parse` will return:

```elixir
%{
  "INTERFACE" => ["GigabitEthernet0/0", "GigabitEthernet0/1",
   "GigabitEthernet0/2", "Loopback0"],
  "IP_ADDRESS" => ["192.168.1.1", "unassigned", "10.0.0.5", "127.0.0.1"],
  "PROTOCOL" => ["up", "down", "up", "up"],
  "STATUS" => ["up", "administratively down", "up", "up"]
}
```

## Caveats

- Comments in templates are yet to be supported
- The template parser is strict regarding how many whitespaces you use (e.g. when defining values)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `textfsm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:textfsm, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/textfsm>.
