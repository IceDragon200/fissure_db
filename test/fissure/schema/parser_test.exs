defmodule Fissure.Schema.ParserTest do
  use ExUnit.Case

  alias Fissure.Schema.Parser

  describe "parse_word/1" do
    test "can parse simple words" do
      assert {"hello", ""} = Parser.parse_word("hello")
    end

    test "can properly parse just the word from a binary" do
      assert {"name", "=value"} = Parser.parse_word("name=value")
    end
  end

  describe "parse_quoted_string/1" do
    test "can parse a quoted string" do
      assert {"Hello, World", ""} = Parser.parse_quoted_string("\"Hello, World\"")
    end
  end
end
