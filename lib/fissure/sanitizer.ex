defmodule Fissure.Sanitizer do
  def presence(nil) do
    nil
  end

  def presence("") do
    nil
  end

  def presence(rest) do
    rest
  end

  def sanitize_path_component(path) do
    Path.expand(path, "/")
  end
end
