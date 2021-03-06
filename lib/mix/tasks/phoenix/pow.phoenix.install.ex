defmodule Mix.Tasks.Pow.Phoenix.Install do
  @shortdoc "Prints instructions for setting up Pow with Phoenix"

  @moduledoc """
  Prints instructions fo setting up Pow with Phoenix.

      mix pow.phoenix.install -r MyApp.Repo

      mix pow.phoenix.install -r MyApp.Repo --context-app :my_app

      mix pow.phoenix.install -r MyApp.Repo --templates --extension PowResetPassword

  Templates are only generated when `--templates` argument is provided.

  See `Mix.Tasks.Pow.Phoenix.Gen.Templates` and
  `Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates` for more.

  ## Arguments

    * `--context-app` app to use for path and module names
    * `--templates` generate templates and views
    * `--extension` - extensions to generate templates for
  """
  use Mix.Task

  alias Mix.Tasks.Pow.Phoenix.Gen.Templates, as: PhoenixTemplatesTask
  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates, as: PhoenixExtensionTemplatesTask
  alias Mix.{Pow, Pow.Phoenix}

  @switches [context_app: :string, templates: :boolean, extension: :keep]
  @default_opts [templates: false]
  @mix_task "pow.phoenix.install"

  @impl true
  def run(args), do: run(args, Pow.schema_options_from_args())

  @doc false
  def run(args, schema_opts) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse_structure()
    |> maybe_run_gen_templates(args)
    |> maybe_run_extensions_gen_templates(args)
    |> print_shell_instructions(schema_opts)
  end

  defp parse_structure({config, _parsed, _invalid}) do
    Map.put(config, :structure, Phoenix.parse_structure(config))
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    PhoenixTemplatesTask.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config

  defp maybe_run_extensions_gen_templates(%{templates: true, extension: extensions} = config, args) when extensions != [] do
    PhoenixExtensionTemplatesTask.run(args)

    config
  end
  defp maybe_run_extensions_gen_templates(config, _args), do: config

  defp print_shell_instructions(%{structure: structure}, %{schema_name: schema_name}) do
    context_base = structure[:context_base]
    web_base     = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Mix.shell.info("""
    Pow has been installed in your phoenix app!

    There are three files you'll need to configure first before you can use Pow.

    First, append this to `config/config.ex`:

    config :#{Macro.underscore(context_base)}, :pow,
      user: #{inspect(context_base)}.#{schema_name},
      repo: #{inspect(context_base)}.Repo

    Next, add `Pow.Plug.Session` plug to `#{web_prefix}/endpoint.ex`:

    defmodule #{inspect(web_base)}.Endpoint do
      use Phoenix.Endpoint, otp_app: :#{Macro.underscore(context_base)}

      # ...

      plug Plug.Session,
        store: :cookie,
        key: "_#{Macro.underscore(context_base)}_key",
        signing_salt: "secret"

      plug Pow.Plug.Session, otp_app: :#{Macro.underscore(context_base)}

      # ...
    end

    Last, update` #{web_prefix}/router.ex` with the Pow routes:

    defmodule #{inspect(web_base)}.Router do
      use #{inspect(web_base)}, :router
      use Pow.Phoenix.Router

      # ... pipelines

      scope "/" do
        pipe_through :browser

        pow_routes()
      end

      # ... routes
    end
    """)
  end
end
