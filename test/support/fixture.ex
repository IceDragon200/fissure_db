defmodule Fissure.Fixture do
  def fixtures_path(path) do
    Path.expand(path, Path.join(Path.dirname(__ENV__.file), "../fixtures"))
  end
end
