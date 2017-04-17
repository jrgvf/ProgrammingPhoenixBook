defmodule Rumbl.Plugs.AuthTest do
  use Rumbl.ConnCase
  alias Rumbl.Plugs.Auth

  setup %{conn: conn} do
    conn = bypass_through(conn, Rumbl.Router, :browser)
    |> get("/")

    {:ok, %{conn: conn}}
  end

  test "authenticate_user halts when no current_user exists", %{conn: conn} do
    conn = Auth.authenticate_user(conn, [])
    assert conn.halted
  end

  test "authenticate_user continues when the current_user exists", %{conn: conn} do
    conn = assign(conn, :current_user, %Rumbl.User{})
    |> Auth.authenticate_user([])
    refute conn.halted
  end

  test "login puts the user in the session", %{conn: conn} do
    login_conn = Auth.login(conn, %Rumbl.User{id: 123})
    |> send_resp(:ok, "")

    next_conn = get(login_conn, "/")
    assert get_session(next_conn, :user_id) == 123
  end

  test "logout drops the session", %{conn: conn} do
    logout_conn = put_session(conn, :user_id, 123)
    |> Auth.logout
    |> send_resp(:ok, "")

    next_conn = get(logout_conn, "/")
    refute get_session(next_conn, :user_id)
  end

  test "call places user from session into assigns", %{conn: conn} do
    user = insert_user()
    conn = put_session(conn, :user_id, user.id)
    |> Auth.call(Repo)

    assert conn.assigns.current_user.id == user.id
  end

  test "call with no session sets current_user assign to nil", %{conn: conn} do
    conn = Auth.call(conn, Repo)
    assert conn.assigns.current_user == nil
  end

  test "login with a valid username ans pass", %{conn: conn} do
    user = insert_user(username: "me", password: "secret")
    {:ok, conn} = Auth.login_by_username_and_pass(conn, "me", "secret", repo: Repo)
    assert conn.assigns.current_user.id == user.id
  end

  test "login with a not found user", %{conn: conn} do
    assert {:error, :not_found, _conn} = Auth.login_by_username_and_pass(conn, "me", "secret", repo: Repo)
  end

  test "login with a password mismatch", %{conn: conn} do
    _user = insert_user(username: "me", password: "secret")
    assert {:error, :unauthorized, _conn} = Auth.login_by_username_and_pass(conn, "me", "wrong", repo: Repo)
  end
end