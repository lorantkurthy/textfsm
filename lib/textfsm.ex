defmodule TextFSM do
  alias __MODULE__.Template

  def parse(template) do
    with {:ok, [template], _, _, _, _} <- Template.template(template),
         :ok <- Template.Validator.validate(template) do
      {:ok, template}
    else
      {:error, reason, rest, context, line, byte_offset} ->
        {:error, reason, rest, context, line, byte_offset}

      validation_errors ->
        validation_errors
    end
  end
end
