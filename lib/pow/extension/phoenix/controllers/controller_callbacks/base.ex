defmodule Pow.Extension.Phoenix.ControllerCallbacks.Base do
  @moduledoc """
  Used for the Phoenix Controller Callbacks module in extensions.

  ## Usage

      defmodule MyPowExtension.Phoenix.ControllerCallbacks do
        use Pow.Extension.Phoenix.ControllerCallbacks.Base

        @impl true
        def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
          {:ok, user, conn}
        end
      end
  """
  alias Pow.{Config, Extension.Phoenix.Controller.Base}

  @callback before_process(atom(), atom(), any(), Config.t()) :: any()
  @callback before_respond(atom(), atom(), any(), Config.t()) :: any()

  @doc false
  defmacro __using__(_config) do
    quote do
      @behaviour unquote(__MODULE__)

      import Base, only: [__define_helper_methods__: 0]

      __define_helper_methods__()

      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(_opts) do
    for hook <- [:before_process, :before_respond] do
      quote do
        @spec unquote(hook)(atom(), atom(), any(), Config.t()) :: any()
        def unquote(hook)(_controller, _action, res, _config), do: res
      end
    end
  end
end
