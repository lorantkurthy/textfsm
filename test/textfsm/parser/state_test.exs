defmodule TextFSM.Parser.StateTest do
  use ExUnit.Case

  alias TextFSM.Template.State
  alias State.{Rule, Rule.Action, Rule.ErrorAction}
  import State

  describe "state/1" do
    test "parses state with no rules" do
      text = "Start"

      assert_state(text, "Start", [])
    end

    test "parses state with single simple rule" do
      text = """
      Start
        ^Hello World
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?H, ?e, ?l, ?l, ?o, ?\s, ?W, ?o, ?r, ?l, ?d],
          action: %Action{}
        }
      ]

      assert_state(text, "Start", expected_rules)
    end

    test "parses state with multiple simple rules" do
      text = """
      ProcessData
        ^First Line
        ^Second Line
        ^Third Line
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?F, ?i, ?r, ?s, ?t, ?\s, ?L, ?i, ?n, ?e],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [?^, ?S, ?e, ?c, ?o, ?n, ?d, ?\s, ?L, ?i, ?n, ?e],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [?^, ?T, ?h, ?i, ?r, ?d, ?\s, ?L, ?i, ?n, ?e],
          action: %Action{}
        }
      ]

      assert_state(text, "ProcessData", expected_rules)
    end

    test "parses state with rules containing value descriptors" do
      text = """
      Interface
        ^Interface ${InterfaceName}
        ^IP Address: ${IPAddress}
      """

      expected_rules = [
        %Rule{
          regex_tokens: [
            ?^,
            ?I,
            ?n,
            ?t,
            ?e,
            ?r,
            ?f,
            ?a,
            ?c,
            ?e,
            ?\s,
            {:value_descriptor, "InterfaceName"}
          ],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [
            ?^,
            ?I,
            ?P,
            ?\s,
            ?A,
            ?d,
            ?d,
            ?r,
            ?e,
            ?s,
            ?s,
            ?:,
            ?\s,
            {:value_descriptor, "IPAddress"}
          ],
          action: %Action{}
        }
      ]

      assert_state(text, "Interface", expected_rules)
    end

    test "parses state with rules containing actions" do
      text = """
      Main
        ^Start -> Record
        ^Process -> Continue
        ^End -> Next
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?S, ?t, ?a, ?r, ?t],
          action: %Action{
            line_action: :next,
            record_action: :record,
            next_state: nil
          }
        },
        %Rule{
          regex_tokens: [?^, ?P, ?r, ?o, ?c, ?e, ?s, ?s],
          action: %Action{
            line_action: :continue,
            record_action: :no_record,
            next_state: nil
          }
        },
        %Rule{
          regex_tokens: [?^, ?E, ?n, ?d],
          action: %Action{
            line_action: :next,
            record_action: :no_record,
            next_state: nil
          }
        }
      ]

      assert_state(text, "Main", expected_rules)
    end

    test "parses state with rules containing state transitions" do
      text = """
      Start
        ^Begin -> ProcessState
        ^Error -> ErrorState
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?B, ?e, ?g, ?i, ?n],
          action: %Action{
            line_action: :next,
            record_action: :no_record,
            next_state: "ProcessState"
          }
        },
        %Rule{
          regex_tokens: [?^, ?E, ?r, ?r, ?o, ?r],
          action: %Action{
            line_action: :next,
            record_action: :no_record,
            next_state: "ErrorState"
          }
        }
      ]

      assert_state(text, "Start", expected_rules)
    end

    test "parses state with combined actions and state transitions" do
      text = """
      DataProcessor
        ^${Name} -> Record NextState
        ^${Value} -> Continue.Record ProcessValue
        ^Done -> Next.Clear End
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, {:value_descriptor, "Name"}],
          action: %Action{
            line_action: :next,
            record_action: :record,
            next_state: "NextState"
          }
        },
        %Rule{
          regex_tokens: [?^, {:value_descriptor, "Value"}],
          action: %Action{
            line_action: :continue,
            record_action: :record,
            next_state: "ProcessValue"
          }
        },
        %Rule{
          regex_tokens: [?^, ?D, ?o, ?n, ?e],
          action: %Action{
            line_action: :next,
            record_action: :clear,
            next_state: "End"
          }
        }
      ]

      assert_state(text, "DataProcessor", expected_rules)
    end

    test "parses state with error actions" do
      text = """
      Validator
        ^Invalid -> Error "Invalid input detected"
        ^Bad -> Error "Bad format"
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?I, ?n, ?v, ?a, ?l, ?i, ?d],
          action: %ErrorAction{message: "Invalid input detected"}
        },
        %Rule{
          regex_tokens: [?^, ?B, ?a, ?d],
          action: %ErrorAction{message: "Bad format"}
        }
      ]

      assert_state(text, "Validator", expected_rules)
    end

    test "parses state with complex regex patterns" do
      text = """
      Parser
        ^\\s*\\d+\\.\\d+\\.\\d+\\.\\d+
        ^[A-Z][a-z]+ \\w+
        ^(test|prod|dev)
      """

      expected_rules = [
        %Rule{
          regex_tokens: [
            ?^,
            ?\\,
            ?s,
            ?*,
            ?\\,
            ?d,
            ?+,
            ?\\,
            ?.,
            ?\\,
            ?d,
            ?+,
            ?\\,
            ?.,
            ?\\,
            ?d,
            ?+,
            ?\\,
            ?.,
            ?\\,
            ?d,
            ?+
          ],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [
            ?^,
            ?[,
            ?A,
            ?-,
            ?Z,
            ?],
            ?[,
            ?a,
            ?-,
            ?z,
            ?],
            ?+,
            ?\s,
            ?\\,
            ?w,
            ?+
          ],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [
            ?^,
            ?(,
            ?t,
            ?e,
            ?s,
            ?t,
            ?|,
            ?p,
            ?r,
            ?o,
            ?d,
            ?|,
            ?d,
            ?e,
            ?v,
            ?)
          ],
          action: %Action{}
        }
      ]

      assert_state(text, "Parser", expected_rules)
    end

    test "parses state with mixed rule types" do
      text = """
      MixedState
        ^Simple line
        ^${Variable} with descriptor
        ^Pattern -> Record
        ^${Name} -> Continue.Clear NextState
        ^Error case -> Error "Something went wrong"
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?S, ?i, ?m, ?p, ?l, ?e, ?\s, ?l, ?i, ?n, ?e],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [
            ?^,
            {:value_descriptor, "Variable"},
            ?\s,
            ?w,
            ?i,
            ?t,
            ?h,
            ?\s,
            ?d,
            ?e,
            ?s,
            ?c,
            ?r,
            ?i,
            ?p,
            ?t,
            ?o,
            ?r
          ],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [?^, ?P, ?a, ?t, ?t, ?e, ?r, ?n],
          action: %Action{
            line_action: :next,
            record_action: :record,
            next_state: nil
          }
        },
        %Rule{
          regex_tokens: [?^, {:value_descriptor, "Name"}],
          action: %Action{
            line_action: :continue,
            record_action: :clear,
            next_state: "NextState"
          }
        },
        %Rule{
          regex_tokens: [?^, ?E, ?r, ?r, ?o, ?r, ?\s, ?c, ?a, ?s, ?e],
          action: %ErrorAction{message: "Something went wrong"}
        }
      ]

      assert_state(text, "MixedState", expected_rules)
    end

    test "parses state with escaped dollar signs" do
      text = """
      PriceState
        ^Price: $$100
        ^Total: $$${Amount}
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?P, ?r, ?i, ?c, ?e, ?:, ?\s, "$$", ?1, ?0, ?0],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [?^, ?T, ?o, ?t, ?a, ?l, ?:, ?\s, "$$", {:value_descriptor, "Amount"}],
          action: %Action{}
        }
      ]

      assert_state(text, "PriceState", expected_rules)
    end

    test "parses state with clearall actions" do
      text = """
      ResetState
        ^Clear -> Clearall
        ^Reset -> Continue.Clearall NextState
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?C, ?l, ?e, ?a, ?r],
          action: %Action{
            line_action: :next,
            record_action: :clear_all,
            next_state: nil
          }
        },
        %Rule{
          regex_tokens: [?^, ?R, ?e, ?s, ?e, ?t],
          action: %Action{
            line_action: :continue,
            record_action: :clear_all,
            next_state: "NextState"
          }
        }
      ]

      assert_state(text, "ResetState", expected_rules)
    end

    test "parses state with NoRecord action" do
      text = """
      SkipState
        ^Skip this -> NoRecord
        ^Ignore -> NoRecord SkipState
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?S, ?k, ?i, ?p, ?\s, ?t, ?h, ?i, ?s],
          action: %Action{
            line_action: :next,
            record_action: :no_record,
            next_state: nil
          }
        },
        %Rule{
          regex_tokens: [?^, ?I, ?g, ?n, ?o, ?r, ?e],
          action: %Action{
            line_action: :next,
            record_action: :no_record,
            next_state: "SkipState"
          }
        }
      ]

      assert_state(text, "SkipState", expected_rules)
    end

    test "parses state with underscored name" do
      text = """
      Process_Data_State
        ^Start processing
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?S, ?t, ?a, ?r, ?t, ?\s, ?p, ?r, ?o, ?c, ?e, ?s, ?s, ?i, ?n, ?g],
          action: %Action{}
        }
      ]

      assert_state(text, "Process_Data_State", expected_rules)
    end

    test "parses state with numeric characters in name" do
      text = """
      State123
        ^Test pattern
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?T, ?e, ?s, ?t, ?\s, ?p, ?a, ?t, ?t, ?e, ?r, ?n],
          action: %Action{}
        }
      ]

      assert_state(text, "State123", expected_rules)
    end
  end

  describe "state/1 edge cases" do
    test "parses state with single character name" do
      text = """
      A
        ^Pattern
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^, ?P, ?a, ?t, ?t, ?e, ?r, ?n],
          action: %Action{}
        }
      ]

      assert_state(text, "A", expected_rules)
    end

    test "parses state with only empty regex rules" do
      text = """
      EmptyPatterns
        ^
        ^
      """

      expected_rules = [
        %Rule{
          regex_tokens: [?^],
          action: %Action{}
        },
        %Rule{
          regex_tokens: [?^],
          action: %Action{}
        }
      ]

      assert_state(text, "EmptyPatterns", expected_rules)
    end
  end

  defp assert_state(text, expected_name, expected_rules) do
    assert {:ok, parsed, rest, _context, _line, _byte_offset} = state(text)
    assert rest == "" or String.trim(rest) == ""

    assert [
             %State{
               name: ^expected_name,
               rules: ^expected_rules
             }
           ] = parsed
  end
end
