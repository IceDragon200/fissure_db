defmodule Fissure.Schema.Field do
  defmodule Attributes do
    defstruct [
      nilable: true,
      default: nil,
    ]

    @type t :: %__MODULE__{
      nilable: boolean(),
      default: term(),
    }
  end

  defstruct [
    :name,
    :type,
    :attributes,
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    type: String.t(),
    attributes: Attributes.t(),
  }
end
