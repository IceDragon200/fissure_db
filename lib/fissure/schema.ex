defmodule Fissure.Schema do
  @moduledoc """
  File Structure:

      # comment
      name=NAME
      primary_key=FIELD
      field=FIELD TYPE [default=VALUE] [nilable=BOOLEAN]
      index=NAME (FIELD...) [unique=BOOLEAN]

  field and index can be repeated multiple times
  """
  import Fissure.Sanitizer

  alias Fissure.Schema.Parser
  alias Fissure.Schema.Index
  alias Fissure.Schema.Field

  defstruct [
    name: nil,
    primary_key: nil,
    fields: %{},
    indices: %{},
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    primary_key: String.t(),
    fields: %{String.t() => Field.t()},
    indices: %{String.t() => Index.t()},
  }

  def fetch_field_with_schema(row, field, %__MODULE__{} = schema) do
    case Map.fetch(schema.fields, field) do
      {:ok, field} ->
        Map.fetch(row, field.name)

      :error ->
        :error
    end
  end

  def verify_row_integrity_with_schema(row, %__MODULE__{} = schema) when is_map(row) do
    try do
      result =
        Enum.reduce(schema.fields, %{}, fn {_field_name, %Field{} = field}, acc ->
          case Map.get(row, field.name) do
            nil ->
              if field.attributes.nilable do
                Map.put(acc, field.name, nil)
              else
                throw {:error, {:nil_constraint_violation, field.name}}
              end

            val ->
              # FIXME: verify type
              Map.put(acc, field.name, val)
          end
        end)

      {:ok, result}
    catch {:error, _} = err ->
      err
    end
  end

  def create_item_file_with_schema(items_path, row, %__MODULE__{} = schema) when is_map(row) do
    case verify_row_integrity_with_schema(row, schema) do
      {:ok, row} when is_map(row) ->
        case fetch_field_with_schema(row, schema.primary_key, schema) do
          {:ok, id} ->
            path = Path.join(items_path, id)

            case File.stat(path) do
              {:ok, %File.Stat{}} ->
                {:error, {:conflict, id}}

              {:error, :enoent} ->
                case File.mkdir_p(path) do
                  :ok ->
                    Enum.each(row, fn {field, value} ->
                      field_path = Path.join(path, field)

                      # FIXME: dump value correctly
                      File.write!(field_path, value)
                    end)

                    {:ok, row}
                end
            end

          :error ->
            {:error, {:missing_primary_key, schema.primary_key}}
        end

      {:error, _} = err ->
        err
    end
  end

  @spec load_item_from_file_with_schema(Path.t(), String.t(), t()) :: {:ok, map()}
  def load_item_from_file_with_schema(items_path, id, %__MODULE__{} = schema) do
    id = sanitize_path_component(id)
    path = Path.join(items_path, id)

    case File.stat(path) do
      {:ok, %File.Stat{}} ->
        result =
          Enum.reduce(schema.fields, %{}, fn %Field{} = field, acc ->
            field_path = Path.join(path, field.name)

            case File.stat(field_path) do
              {:ok, %File.Stat{} = _stat} ->
                content = File.read!(field_path)
                # FIXME: cast content as correct type
                Map.put(acc, field.name, content)

              {:error, :enoent} ->
                Map.put(acc, field.name, nil)
            end
          end)

        {:ok, result}

      {:error, :enoent} ->
        {:error, :item_not_found}
    end
  end

  @spec load_schema_from_file(Path.t()) :: {:ok, t()}
  def load_schema_from_file(filename) do
    File.open(filename, [:read], fn file ->
      load_schema_from_io(file)
    end)
  end

  def load_schema_from_io(device) do
    do_load_schema_from_io(device, %__MODULE__{})
  end

  defp do_load_schema_from_io(device, %__MODULE__{} = schema) do
    case IO.read(device, :line) do
      :eof ->
        validate_schema!(schema)

      <<"#", _comment::binary>> ->
        do_load_schema_from_io(device, schema)

      <<"name=", name::binary>> ->
        name = String.trim(name)
        do_load_schema_from_io(device, %{schema | name: name})

      <<"primary_key=", field::binary>> ->
        field = String.trim(field)
        do_load_schema_from_io(device, %{schema | primary_key: field})

      <<"field=", field_def::binary>> ->
        {field, ""} = Parser.parse_field_def(field_def)
        do_load_schema_from_io(device, put_in(schema.fields[field.name], field))

      <<"index=", index_def::binary>> ->
        {index, ""} = Parser.parse_index_def(index_def)
        do_load_schema_from_io(device, put_in(schema.indices[index.name], index))

      line ->
        "" = String.trim(line)
        do_load_schema_from_io(device, schema)
    end
  end

  defp validate_schema!(schema) do
    case presence(schema.name) do
      nil ->
        throw {:schema_error, "name is required"}

      _ ->
        :ok
    end

    case presence(schema.primary_key) do
      nil ->
        throw {:primary_key_error, "primary_key is required"}

      _ ->
        :ok
    end

    Enum.each(schema.indices, fn {name, index} ->
      Enum.each(index.fields, fn field ->
        case schema.fields[field] do
          nil ->
            throw {:index_error, name, {:field_not_defined, field}}

          %Field{} ->
            :ok
        end
      end)
    end)

    schema
  end
end
