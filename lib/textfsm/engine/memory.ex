defmodule TextFSM.Engine.Memory do
  defstruct [
    :table,
    :accumulator,
    :num_rows,
    :match_constraints,
    :key_group_to_row_idx,
    :key_group_to_pending_rows
  ]

  alias TextFSM.{Template, Engine.MatchConstraints}
  alias Template.ValueDefinition

  @type value_name() :: String.t()

  @type value() :: nil | :fillup | String.t() | [String.t()]

  @type table() :: %{value_name() => [value()]}

  @type finalized_value() :: nil | String.t() | [String.t()]

  @type finalized_table() :: %{value_name() => [finalized_value()]}

  @type row() :: %{value_name() => value()}

  @type match() :: nil | String.t()

  @type key() :: row()

  @type key_group() :: MapSet.t(key())

  @type row_idx() :: non_neg_integer()

  @type key_group_to_row_idx() :: %{key_group() => row_idx()}

  @type key_group_to_pending_rows() :: %{key_group() => [row()]}

  @type t() :: %__MODULE__{
          table: table(),
          accumulator: row(),
          num_rows: non_neg_integer(),
          match_constraints: MatchConstraints.t(),
          key_group_to_row_idx: key_group_to_row_idx()
        }

  @spec new([ValueDefinition.t()]) :: t()
  def new(value_definitions) do
    %__MODULE__{
      table: Map.new(value_definitions, &{&1.name, []}),
      accumulator: %{},
      num_rows: 0,
      match_constraints: MatchConstraints.new(value_definitions),
      key_group_to_row_idx: %{},
      key_group_to_pending_rows: %{}
    }
  end

  @spec collect(t(), value_name(), match()) :: t()
  def collect(
        %__MODULE__{accumulator: accumulator, match_constraints: match_constraints} = memory,
        value_name,
        match
      ) do
    value =
      cond do
        not is_nil(match) and MatchConstraints.list?(match_constraints, value_name) ->
          prepend(accumulator, value_name, match)

        true ->
          match
      end

    %{memory | accumulator: Map.put(accumulator, value_name, value)}
  end

  @spec record(t(), boolean()) :: t()
  def record(
        %__MODULE__{
          table: table,
          accumulator: accumulator,
          num_rows: num_rows,
          match_constraints: match_constraints,
          key_group_to_row_idx: key_group_to_row_idx,
          key_group_to_pending_rows: key_group_to_pending_rows
        } =
          memory,
        eof_state? \\ false
      ) do
    cond do
      eof_state? and dummy_accumulator?(match_constraints, accumulator) ->
        memory

      empty_accumulator?(accumulator) or missing_required_value?(memory) ->
        memory

      true ->
        row =
          table
          |> Map.keys()
          |> Map.new(fn value_name ->
            value = Map.get(accumulator, value_name)

            value =
              cond do
                MatchConstraints.fillup?(match_constraints, value_name) ->
                  value || :fillup

                true ->
                  value
              end

            {value_name, value}
          end)

        key_group = compute_key_group(memory, row)

        {table, num_rows, key_group_to_row_idx, key_group_to_pending_rows} =
          cond do
            Map.has_key?(key_group_to_row_idx, key_group) and
                not empty_pending_row?(match_constraints, row) ->
              {table, num_rows, key_group_to_row_idx,
               Map.update(key_group_to_pending_rows, key_group, [row], &[row | &1])}

            not is_nil(key_group) ->
              {append_row(table, row), num_rows + 1,
               Map.put_new(key_group_to_row_idx, key_group, num_rows), key_group_to_pending_rows}

            true ->
              {append_row(table, row), num_rows + 1, key_group_to_row_idx,
               key_group_to_pending_rows}
          end

        %{
          memory
          | table: table,
            num_rows: num_rows,
            key_group_to_row_idx: key_group_to_row_idx,
            key_group_to_pending_rows: key_group_to_pending_rows
        }
        |> clear()
    end
  end

  @spec clear(t()) :: t()
  def clear(%__MODULE__{accumulator: accumulator, match_constraints: match_constraints} = memory) do
    accumulator =
      Map.reject(accumulator, fn {value_name, _match} ->
        not MatchConstraints.filldown?(match_constraints, value_name)
      end)

    %{memory | accumulator: accumulator}
  end

  @spec clear_all(t()) :: t()
  def clear_all(%__MODULE__{} = memory) do
    %{memory | accumulator: %{}}
  end

  @spec finalize(t()) :: finalized_table()
  def finalize(
        %__MODULE__{
          table: table
        } = memory
      ) do
    table =
      Map.new(table, fn {value_name, column} ->
        {value_name, Enum.reverse(column)}
      end)

    %{memory | table: table}
    |> merge_pending_rows()
    |> populate_fillups()
  end

  defp merge_pending_rows(
         %__MODULE__{
           table: table,
           match_constraints: match_constraints,
           key_group_to_row_idx: key_group_to_row_idx,
           key_group_to_pending_rows: key_group_to_pending_rows
         } = memory
       ) do
    table =
      Enum.reduce(
        key_group_to_row_idx,
        table,
        fn {key_group, row_idx}, table ->
          row = get_row(table, row_idx)

          pending_rows =
            Map.get(key_group_to_pending_rows, key_group)

          if is_nil(pending_rows) do
            table
          else
            merged_rows =
              pending_rows
              |> Enum.reverse()
              |> Enum.reduce(
                row,
                fn pending_row, acc ->
                  merge_rows(match_constraints, acc, pending_row)
                end
              )

            replace_row(table, row_idx, merged_rows)
          end
        end
      )

    %{memory | table: table}
  end

  defp replace_row(table, idx, row) do
    Map.new(
      table,
      fn {value_name, column} ->
        new_value = row[value_name]
        {value_name, List.replace_at(column, idx, new_value)}
      end
    )
  end

  defp get_row(table, idx) do
    Map.new(
      table,
      fn {value_name, column} -> {value_name, Enum.at(column, idx)} end
    )
  end

  defp merge_rows(match_constraints, row, new_row) do
    Map.merge(row, new_row, fn value_name, value1, value2 ->
      cond do
        MatchConstraints.key?(match_constraints, value_name) ->
          value1

        MatchConstraints.list?(match_constraints, value_name) ->
          value1 ++ value2

        true ->
          value2
      end
    end)
  end

  defp compute_key_group(%__MODULE__{table: table, match_constraints: match_constraints}, row) do
    base_key_group =
      table
      |> Map.keys()
      |> Enum.filter(&MatchConstraints.key?(match_constraints, &1))
      |> Map.new(&{&1, nil})

    key_group =
      Map.reject(row, fn {value_name, _value} ->
        not MatchConstraints.key?(match_constraints, value_name)
      end)

    if key_group == %{} do
      nil
    else
      Map.merge(base_key_group, key_group)
    end
  end

  defp append_row(table, row) do
    Map.new(
      table,
      fn {value_name, column} ->
        value = Map.get(row, value_name)
        {value_name, [value | column]}
      end
    )
  end

  defp prepend(accumulator, value_name, match) do
    value = Map.get(accumulator, value_name, [])
    [match | value]
  end

  defp empty_accumulator?(accumulator) do
    Enum.all?(accumulator, fn {_value_name, match} ->
      is_nil(match)
    end)
  end

  defp empty_pending_row?(match_constraints, row) do
    Enum.all?(row, fn {value_name, match} ->
      is_nil(match) or MatchConstraints.key?(match_constraints, value_name) or
        MatchConstraints.filldown?(match_constraints, value_name)
    end)
  end

  defp dummy_accumulator?(match_constraints, row) do
    Enum.all?(row, fn {value_name, match} ->
      is_nil(match) or MatchConstraints.key?(match_constraints, value_name) or
        MatchConstraints.filldown?(match_constraints, value_name)
    end)
  end

  defp missing_required_value?(%__MODULE__{
         accumulator: accumulator,
         match_constraints: match_constraints
       }) do
    accumulator
    |> Enum.any?(fn {value_name, match} ->
      MatchConstraints.required?(match_constraints, value_name) and
        is_nil(match)
    end)
  end

  defp populate_fillups(%__MODULE__{table: table, match_constraints: match_constraints}) do
    fillup_columns =
      Map.reject(table, fn {value_name, _column} ->
        not MatchConstraints.fillup?(match_constraints, value_name)
      end)

    populated_columns =
      Map.new(fillup_columns, fn {value_name, column} ->
        {value_name, populate_fillup_column(column)}
      end)

    Map.merge(table, populated_columns)
  end

  defp populate_fillup_column(column) do
    {_, populated_column} =
      column
      |> Enum.reverse()
      |> Enum.reduce(
        {nil, []},
        fn value, {fillup_value, column} ->
          case value do
            :fillup ->
              {fillup_value, [fillup_value | column]}

            fillup_value ->
              {fillup_value, [fillup_value | column]}
          end
        end
      )

    populated_column
  end
end
