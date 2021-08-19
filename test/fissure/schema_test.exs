defmodule Fissure.SchemaTest do
  use ExUnit.Case

  alias Fissure.Schema

  import Fissure.Fixture

  describe "load_schema_from_file/1" do
    test "can load a schema" do
      path = fixtures_path("schemas/users.schema")

      IO.inspect path

      assert {:ok, %Schema{
        fields: %{
          "id" => %Schema.Field{
            type: "uuid",
            attributes: %{
              nilable: false,
            }
          },
          "email" => %Schema.Field{
            type: "string",
            attributes: %{
              nilable: false,
            }
          },
          "notes" => %Schema.Field{
            type: "string",
          },
        },
        indices: %{
          "email_unique_idx" => %Schema.Index{
            fields: ["email"],
            attributes: %{
              unique: true,
            },
          }
        }
      }} = Fissure.Schema.load_schema_from_file(path)
    end
  end
end
