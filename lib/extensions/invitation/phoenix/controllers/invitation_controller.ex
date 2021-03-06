defmodule PowInvitation.Phoenix.InvitationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias Pow.Phoenix.{RegistrationController, SessionController}
  alias PowInvitation.{Phoenix.Mailer, Plug}

  plug :require_authenticated when action in [:new, :create, :show]
  plug :require_not_authenticated when action in [:edit, :update]
  plug :load_user_from_invitation_token when action in [:show, :edit, :update]
  plug :assign_create_path when action in [:new, :create]
  plug :assign_update_path when action in [:edit, :update]

  @spec process_new(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_new(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @spec respond_new({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  @spec process_create(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_create(conn, %{"user" => user_params}) do
    Plug.create_user(conn, user_params)
  end

  @spec respond_create({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, %{email: email} = user, conn}) when is_binary(email) do
    deliver_email(conn, user)

    conn
    |> put_flash(:info, messages(conn).invitation_email_sent(conn))
    |> redirect(to: routes(conn).path_for(conn, __MODULE__, :new))
  end
  def respond_create({:ok, user, conn}) do
    redirect(conn, to: routes(conn).path_for(conn, __MODULE__, :show, [user.invitation_token]))
  end
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  defp deliver_email(conn, user) do
    url        = invitation_url(conn, user)
    invited_by = Pow.Plug.current_user(conn)
    email      = Mailer.invitation(conn, user, invited_by, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end

  defp invitation_url(conn, user) do
    routes(conn).url_for(conn, __MODULE__, :edit, [user.invitation_token])
  end

  @spec process_show(Conn.t(), map()) :: {:ok, Conn.t()}
  def process_show(conn, _params), do: {:ok, conn}

  @spec respond_show({:ok, Conn.t()}) :: Conn.t()
  def respond_show({:ok, %{assigns: %{invited_user: user}} = conn}) do
    conn
    |> assign(:url, invitation_url(conn, user))
    |> render("show.html")
  end

  @spec process_edit(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_edit(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @spec respond_edit({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_edit({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  @spec process_update(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_update(conn, %{"user" => user_params}) do
    Plug.update_user(conn, user_params)
  end

  @spec respond_update({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_update({:ok, _user, conn}) do
    conn
    |> put_flash(:info, RegistrationController.messages(conn).user_has_been_created(conn))
    |> redirect(to: routes(conn).after_registration_path(conn))
  end
  def respond_update({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  defp load_user_from_invitation_token(%{params: %{"id" => token}} = conn, _opts) do
    case Plug.invited_user_from_token(conn, token) do
      nil  ->
        conn
        |> put_flash(:error, messages(conn).invalid_invitation(conn))
        |> redirect(to: routes(conn).path_for(conn, SessionController, :new))
        |> halt()

      user ->
        Plug.assign_invited_user(conn, user)
    end
  end

  defp assign_create_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :create)
    Conn.assign(conn, :action, path)
  end

  defp assign_update_path(%{params: %{"id" => token}} = conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :update, [token])
    Conn.assign(conn, :action, path)
  end
end
