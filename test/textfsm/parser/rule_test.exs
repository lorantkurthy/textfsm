defmodule TextFSM.Parser.RuleTest do
  use ExUnit.Case

  alias TextFSM.Template.State
  alias State.{Rule, Rule.Action, Rule.ErrorAction}
  import Rule

  describe "rule/1" do
    test "parses simple rule with literal text" do
      text = "^Hello World"

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o, ?\s, ?W, ?o, ?r, ?l, ?d], %Action{})
    end

    test "parses rule with value descriptor" do
      text = ~S(^Interface ${Interface})

      expected_tokens = [
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
        {:value_descriptor, "Interface"}
      ]

      assert_rule(text, expected_tokens, %Action{})
    end

    test "parses rule with multiple value descriptors" do
      text = ~S(^${Name} ${Value} ${Description})

      expected_tokens = [
        ?^,
        {:value_descriptor, "Name"},
        ?\s,
        {:value_descriptor, "Value"},
        ?\s,
        {:value_descriptor, "Description"}
      ]

      assert_rule(text, expected_tokens, %Action{})
    end

    test "parses rule with escaped dollar sign" do
      text = ~S(^Price: $$100)

      expected_tokens = [?^, ?P, ?r, ?i, ?c, ?e, ?:, ?\s, "$$", ?1, ?0, ?0]

      assert_rule(text, expected_tokens, %Action{})
    end

    test "parses rule with mixed content" do
      text = ~S(^IP: ${IPAddress}, Cost: $$${Cost})

      expected_tokens = [
        ?^,
        ?I,
        ?P,
        ?:,
        ?\s,
        {:value_descriptor, "IPAddress"},
        44,
        ?\s,
        ?C,
        ?o,
        ?s,
        ?t,
        ?:,
        ?\s,
        "$$",
        {:value_descriptor, "Cost"}
      ]

      assert_rule(text, expected_tokens, %Action{})
    end

    test "parses rule with special regex characters" do
      text = "^\\s*\\d+\\.\\d+\\.\\d+\\.\\d+"

      expected_tokens = [
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
      ]

      assert_rule(text, expected_tokens, %Action{})
    end

    test "parses empty rule" do
      text = "^"

      assert_rule(text, [?^], %Action{})
    end
  end

  describe "rule/1 with actions" do
    test "parses rule with next state transition only" do
      text = "^Hello World -> ProcessState"

      expected_action = %Action{
        line_action: :next,
        record_action: :no_record,
        next_state: "ProcessState"
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o, ?\s, ?W, ?o, ?r, ?l, ?d], expected_action)
    end

    test "parses rule with Next line action" do
      text = "^Hello -> Next"

      expected_action = %Action{
        line_action: :next,
        record_action: :no_record,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with Continue line action" do
      text = "^Hello -> Continue"

      expected_action = %Action{
        line_action: :continue,
        record_action: :no_record,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with Record action" do
      text = "^Hello -> Record"

      expected_action = %Action{
        line_action: :next,
        record_action: :record,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with NoRecord action" do
      text = "^Hello -> NoRecord"

      expected_action = %Action{
        line_action: :next,
        record_action: :no_record,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with Clear action" do
      text = "^Hello -> Clear"

      expected_action = %Action{
        line_action: :next,
        record_action: :clear,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with Clearall action" do
      text = "^Hello -> Clearall"

      expected_action = %Action{
        line_action: :next,
        record_action: :clear_all,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with combined line and record actions" do
      text = "^Hello -> Next.Record"

      expected_action = %Action{
        line_action: :next,
        record_action: :record,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with combined Continue.Clear action" do
      text = "^Hello -> Continue.Clear"

      expected_action = %Action{
        line_action: :continue,
        record_action: :clear,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with Continue.Clearall action" do
      text = "^Hello -> Continue.Clearall"

      expected_action = %Action{
        line_action: :continue,
        record_action: :clear_all,
        next_state: nil
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with line action and next state" do
      text = "^Hello -> Next State2"

      expected_action = %Action{
        line_action: :next,
        record_action: :no_record,
        next_state: "State2"
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with record action and next state" do
      text = "^Hello -> Record State2"

      expected_action = %Action{
        line_action: :next,
        record_action: :record,
        next_state: "State2"
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with combined actions and next state" do
      text = "^Hello -> Continue.Record NextState"

      expected_action = %Action{
        line_action: :continue,
        record_action: :record,
        next_state: "NextState"
      }

      assert_rule(text, [?^, ?H, ?e, ?l, ?l, ?o], expected_action)
    end

    test "parses rule with complex regex and combined actions" do
      text = ~S(^${Interface}\s+${Status} -> Record ProcessInterface)

      expected_tokens = [
        ?^,
        {:value_descriptor, "Interface"},
        ?\\,
        ?s,
        ?+,
        {:value_descriptor, "Status"}
      ]

      expected_action = %Action{
        line_action: :next,
        record_action: :record,
        next_state: "ProcessInterface"
      }

      assert_rule(text, expected_tokens, expected_action)
    end
  end

  describe "rule/1 with error actions" do
    test "parses rule with simple error action" do
      text = ~S(^Invalid -> Error "Invalid input")

      expected_action = %ErrorAction{message: "Invalid input"}

      assert_rule(text, [?^, ?I, ?n, ?v, ?a, ?l, ?i, ?d], expected_action)
    end

    test "parses rule with error action containing special characters" do
      text = ~S(^Bad -> Error "Value with special chars: !@#%")

      expected_action = %ErrorAction{message: "Value with special chars: !@#%"}

      assert_rule(text, [?^, ?B, ?a, ?d], expected_action)
    end

    test "parses rule with error action and value descriptor" do
      text = ~S(^${BadValue} -> Error "Unexpected value")

      expected_tokens = [?^, {:value_descriptor, "BadValue"}]
      expected_action = %ErrorAction{message: "Unexpected value"}

      assert_rule(text, expected_tokens, expected_action)
    end
  end

  describe "rule/1 edge cases" do
    test "parses rule with only whitespace in regex" do
      text = "^   "

      assert_rule(text, [?^, ?\s, ?\s, ?\s], %Action{})
    end

    test "parses rule with parentheses" do
      text = "^(test)"

      assert_rule(text, [?^, ?(, ?t, ?e, ?s, ?t, ?)], %Action{})
    end

    test "parses rule with brackets" do
      text = "^[a-z]+"

      assert_rule(text, [?^, ?[, ?a, ?-, ?z, ?], ?+], %Action{})
    end

    test "parses rule with pipe character" do
      text = "^option1|option2"

      assert_rule(
        text,
        [?^, ?o, ?p, ?t, ?i, ?o, ?n, ?1, ?|, ?o, ?p, ?t, ?i, ?o, ?n, ?2],
        %Action{}
      )
    end

    test "parses rule with question mark" do
      text = "^colou?r"

      assert_rule(text, [?^, ?c, ?o, ?l, ?o, ?u, ??, ?r], %Action{})
    end

    test "parses rule with asterisk and plus" do
      text = "^test*word+"

      assert_rule(text, [?^, ?t, ?e, ?s, ?t, ?*, ?w, ?o, ?r, ?d, ?+], %Action{})
    end

    test "parses rule with curly braces in regex" do
      text = "^\\d{1,3}"

      assert_rule(text, [?^, ?\\, ?d, ?{, ?1, ?,, ?3, ?}], %Action{})
    end
  end

  defp assert_rule(text, expected_tokens, expected_action) do
    assert {:ok, parsed, rest, _context, _line, _byte_offset} = rule(text)
    assert rest == ""

    assert [
             %Rule{
               regex_tokens: ^expected_tokens,
               action: ^expected_action
             }
           ] = parsed
  end
end
