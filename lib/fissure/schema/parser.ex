defmodule Fissure.Schema.Parser do
  alias Fissure.Schema.Field
  alias Fissure.Schema.Index

  def parse_field_def(line) do
    rest = String.trim(line)
    {name, rest} = parse_word(rest)
    rest = String.trim_leading(rest)
    {type, rest} = parse_word(rest)

    {attrs, rest} = parse_attributes(rest)
    {%Field{
      name: name,
      type: type,
      attributes: convert_field_attributes(attrs)
    }, rest}
  end

  def convert_field_attributes(attributes) do
    Enum.reduce(attributes, %Field.Attributes{}, fn
      {"nilable", bool}, attrs when is_boolean(bool) ->
        put_in(attrs.nilable, bool)

      {"default", {:word, str}}, attrs ->
        put_in(attrs.default, str)

      {"default", {:quoted, str}}, attrs ->
        put_in(attrs.default, str)

      {"default", value}, attrs when is_nil(value) or is_boolean(value) or is_number(value) ->
        put_in(attrs.default, value)
    end)
  end

  def parse_index_def(line) do
    rest = String.trim(line)
    case String.split(rest, " ", parts: 2) do
      [name, rest] ->
        rest = String.trim_leading(rest)

        case rest do
          <<"(", rest::binary>> ->
            {words, rest} = parse_words(rest)
            rest = String.trim_leading(rest)
            <<")", rest::binary>> = rest
            {attrs, rest} = parse_attributes(rest)

            {%Index{
              name: name,
              fields: words,
              attributes: convert_index_attributes(attrs)
            }, rest}
        end
    end
  end

  def convert_index_attributes(attributes) do
    Enum.reduce(attributes, %Index.Attributes{}, fn
      {"unique", bool}, attrs when is_boolean(bool) ->
        put_in(attrs.unique, bool)
    end)
  end

  def parse_attributes(rest, acc \\ %{})

  def parse_attributes("", acc) do
    {acc, ""}
  end

  def parse_attributes(rest, acc) when is_binary(rest) do
    rest = String.trim_leading(rest)
    {key, <<"=", rest::binary>>} = parse_word(rest)
    rest = String.trim_leading(rest)
    {value, rest} = parse_value(rest)
    acc = Map.put(acc, key, value)
    parse_attributes(rest, acc)
  end

  def parse_value(<<"\"", _rest::binary>> = str) do
    {str, rest} = parse_quoted_string(str)
    {{:quoted, str}, rest}
  end

  def parse_value(str) do
    {word, rest} = parse_word(str)

    case word do
      "true" ->
        {true, rest}

      "false" ->
        {false, rest}

      "nil" ->
        {nil, rest}

      <<"0b", bin::binary>> ->
        case Integer.parse(bin, 2) do
          {val, ""} ->
            {val, rest}

          _ ->
            {{:word, word}, rest}
        end

      <<"0o", oct::binary>> ->
        case Integer.parse(oct, 8) do
          {val, ""} ->
            {val, rest}

          _ ->
            {{:word, word}, rest}
        end

      <<"0x", hex::binary>> ->
        case Integer.parse(hex, 16) do
          {val, ""} ->
            {val, rest}

          _ ->
            {{:word, word}, rest}
        end

      _ ->
        case Integer.parse(word, 10) do
          {val, ""} ->
            {val, rest}

          _ ->
            case Float.parse(word) do
              {val, ""} ->
                {val, rest}

              _ ->
                {{:word, word}, rest}
            end
        end
    end
  end

  def parse_quoted_string(rest, state \\ :start, acc \\ [])

  def parse_quoted_string(<<"\"", rest::binary>>, :start, acc) do
    parse_quoted_string(rest, :body, acc)
  end

  def parse_quoted_string(<<"\\s", rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, ["\s" | acc])
  end

  def parse_quoted_string(<<"\\r", rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, ["\r" | acc])
  end

  def parse_quoted_string(<<"\\n", rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, ["\n" | acc])
  end

  def parse_quoted_string(<<"\\t", rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, ["\t" | acc])
  end

  def parse_quoted_string(<<"\\\"", rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, ["\"" | acc])
  end

  def parse_quoted_string(<<"\"", rest::binary>>, :body, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end

  def parse_quoted_string(<<c::utf8, rest::binary>>, :body, acc) do
    parse_quoted_string(rest, :body, [<<c::utf8>> | acc])
  end

  def parse_words(str, acc \\ [])

  def parse_words("", acc) do
    {Enum.reverse(acc), ""}
  end

  def parse_words(str, acc) do
    {word, rest} = parse_word(str)

    acc = [word | acc]

    case rest do
      <<" ", rest::binary>> ->
        rest = String.trim_leading(rest)
        parse_words(rest, acc)

      _ ->
        {Enum.reverse(acc), rest}
    end
  end

  def parse_word(str, acc \\ [])

  def parse_word(<<c::utf8, rest::binary>>, acc) when (c >= ?A and c <= ?Z) or
                                                      (c >= ?a and c <= ?z) or
                                                      (c >= ?0 and c <= ?9) or
                                                      c == ?_ or c == ?- or c == ?. do
    parse_word(rest, [<<c::utf8>> | acc])
  end

  def parse_word(rest, acc) do
    {IO.iodata_to_binary(Enum.reverse(acc)), rest}
  end
end
