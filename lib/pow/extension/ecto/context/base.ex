defmodule Pow.Extension.Ecto.Context.Base do
  @moduledoc """
  Used for extensions to add helpers for user contexts.

  The macro will add two helper methods to the module:

    * `user_schema_mod/1`
    * `repo/1`

  ## Usage

      defmodule MyPowExtension.Ecto.Context do
        use Pow.Extension.Ecto.Context.Base

        def my_custom_action(_config) do
          mod  = user_schema_mod(config)
          repo = repo(config)

          # ...
        end
      end
  """
  alias Pow.Ecto.Context

  @doc false
  defmacro __using__(_opts) do
    quote do
      def user_schema_mod(config), do: Context.user_schema_mod(config)
      def repo(config), do: Context.repo(config)
    end
  end
end
