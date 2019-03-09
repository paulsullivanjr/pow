defmodule Mix.Pow do
  @moduledoc """
  Utilities module for mix tasks.
  """
  alias Mix.{Dep, Project}

  @doc """
  Raises an exception if the project is an umbrella app.
  """
  @spec no_umbrella!(binary()) :: :ok | no_return
  def no_umbrella!(task) do
    if Project.umbrella?() do
      Mix.raise("mix #{task} can only be run inside an application directory")
    end

    :ok
  end

  @doc """
  Raises an exception if the application doesn't have the dependency.
  """
  @spec ensure_dep!(binary(), atom(), OptionParser.argv()) :: :ok | no_return
  def ensure_dep!(task, dep, _args) do
    []
    |> Dep.load_on_environment()
    |> dep_in_deps?(dep)
    |> case do
      true ->
        :ok

      false ->
        Mix.raise("mix #{task} can only be run inside an application directory that has #{inspect dep} as dependency")
    end
  end

  defp dep_in_deps?(deps, dep) do
    Enum.any?(deps, fn
      %Mix.Dep{app: ^dep} -> true
      _any -> false
    end)
  end

  @doc """
  Raises an exception if application doesn't have Ecto as dependency.
  """
  def ensure_ecto!(task, args), do: ensure_dep!(task, :ecto, args)

  @doc """
  Raises an exception if application doesn't have Phoenix as dependency.
  """
  def ensure_phoenix!(task, args), do: ensure_dep!(task, :phoenix, args)

  @doc """
  Parses argument options into a map.
  """
  @spec parse_options(OptionParser.argv(), Keyword.t(), Keyword.t()) :: {map(), OptionParser.argv(), OptionParser.errors()}
  def parse_options(args, switches, default_opts) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: switches)
    default_opts            = to_map(default_opts)
    opts                    = to_map(opts)
    config                  =
      default_opts
      |> Map.merge(opts)
      |> context_app_to_atom()

    {config, parsed, invalid}
  end

  defp to_map(keyword) do
    Enum.reduce(keyword, %{}, fn {key, value}, map ->
      case Map.get(map, key) do
        nil ->
          Map.put(map, key, value)

        existing_value ->
          value = List.wrap(existing_value) ++ [value]
          Map.put(map, key, value)
      end
    end)
  end

  defp context_app_to_atom(%{context_app: context_app} = config),
    do: Map.put(config, :context_app, String.to_atom(context_app))
  defp context_app_to_atom(config),
    do: config

  @doc """
  Parses arguments into schema name and schema plural.
  """
  @spec schema_options_from_args([binary()]) :: map()
  def schema_options_from_args(_opts \\ [])
  def schema_options_from_args([schema, plural | _rest]), do: %{schema_name: schema, schema_plural: plural}
  def schema_options_from_args(_any), do: %{schema_name: "Users.User", schema_plural: "users"}

  @doc false
  @spec validate_schema_args!([binary()], binary()) :: map()
  def validate_schema_args!([schema, plural | _rest] = args, task) do
    cond do
      not schema_valid?(schema) ->
        raise_invalid_schema_args_error("Expected the schema argument, #{inspect schema}, to be a valid module name", task)
      not plural_valid?(plural) ->
        raise_invalid_schema_args_error("Expected the plural argument, #{inspect plural}, to be all lowercase using snake_case convention", task)
      true ->
        schema_options_from_args(args)
    end
  end
  def validate_schema_args!([_schema | _rest], task) do
    raise_invalid_schema_args_error("Invalid arguments", task)
  end
  def validate_schema_args!([], _task), do: schema_options_from_args()

  defp schema_valid?(schema), do: schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/

  defp plural_valid?(plural), do: plural =~ ~r/^[a-z\_]*$/

  defp raise_invalid_schema_args_error(msg, task) do
    Mix.raise("""
    #{msg}

    mix #{task} accepts both a module name and the plural of the resource:
        mix #{task} Users.User users
    """)
  end

  @doc """
  Fetches context app for the project.
  """
  @spec context_app :: atom() | no_return
  def context_app do
    this_app = otp_app()

    this_app
    |> Application.get_env(:generators, [])
    |> Keyword.get(:context_app)
    |> case do
      nil          -> this_app
      false        -> Mix.raise("No context_app configured for current application")
      {app, _path} -> app
      app          -> app
    end
  end

  defp otp_app do
    Keyword.fetch!(Mix.Project.config(), :app)
  end

  @doc """
  Fetches the context base module for the app.
  """
  @spec context_base(atom()) :: atom()
  def context_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app ->
        app
        |> to_string()
        |> Macro.camelize()
        |> List.wrap()
        |> Module.concat()

      mod ->
        mod
    end
  end

  @doc """
  Fetches the library path for the context app.
  """
  @spec context_lib_path(atom(), Path.t()) :: Path.t()
  def context_lib_path(ctx_app, rel_path) do
    context_app_path(ctx_app, Path.join(["lib", to_string(ctx_app), rel_path]))
  end

  defp context_app_path(ctx_app, rel_path) when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      rel_path
    else
      app_path =
        case Application.get_env(this_app, :generators)[:context_app] do
          {^ctx_app, path} -> Path.relative_to_cwd(path)
          _ -> mix_app_path(ctx_app, this_app)
        end

      Path.join(app_path, rel_path)
    end
  end

  defp mix_app_path(app, this_otp_app) do
    case Mix.Project.deps_paths() do
      %{^app => path} ->
        Path.relative_to_cwd(path)

      _deps ->
        Mix.raise("No directory for context_app #{inspect(app)} found in #{this_otp_app}'s deps.")
    end
  end
end
