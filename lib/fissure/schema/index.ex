defmodule Fissure.Schema.Index do
  defmodule Attributes do
    defstruct [
      unique: false,
    ]

    @type t :: %__MODULE__{
      unique: boolean(),
    }
  end

  defstruct [
    :name,
    :fields,
    :attributes,
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    fields: [String.t()],
    attributes: Attributes.t(),
  }
end
