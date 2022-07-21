defmodule Ueberauth.Strategy.Wordpress do
  @moduledoc """
  Wordpress Strategy for Überauth.
  """

  use Ueberauth.Strategy,
    uid_field: :ID,
    default_scope: "auth",
    send_redirect_uri: true,
    hd: nil,
    userinfo_endpoint: "https://public-api.wordpress.com/rest/v1/me/"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for Wordpress authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    params = with_state_param([scope: scopes, response_type: "code"], conn)
    opts = oauth_client_options_from_conn(conn)
    redirect!(conn, Ueberauth.Strategy.Wordpress.OAuth.authorize_url!(params, opts))
  end

  @doc """
  Handles the callback from Wordpress.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    params = [code: code, grant_type: "authorization_code"]
    opts = oauth_client_options_from_conn(conn)

    case Ueberauth.Strategy.Wordpress.OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:wordpress_user, nil)
    |> put_private(:wordpress_token, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.wordpress_user[uid_field]
  end

  @doc """
  Includes the credentials from the wordpress response.
  """
  def credentials(conn) do
    token = conn.private.wordpress_token
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, ",")

    %Credentials{
      scopes: scopes,
      token_type: Map.get(token, :token_type),
      token: token.access_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.wordpress_user
    # wordpress may not have verified email address yet
    verified = user["verified"] || false

    %Info{
      email: if(verified, do: user["email"], else: nil),
      image: user["avatar_URL"],
      name: user["username"],
      nickname: user["display_name"],
      urls: %{
        profile: user["profile_URL"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the wordpress callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.wordpress_token,
        user: conn.private.wordpress_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :wordpress_token, token)

    # userinfo_endpoint from https://accounts.wordpress.com/.well-known/openid-configuration
    # the userinfo_endpoint may be overridden in options when necessary.
    path =
      case option(conn, :userinfo_endpoint) do
        {:system, varname, default} ->
          System.get_env(varname) || default

        {:system, varname} ->
          System.get_env(varname) || Keyword.get(default_options(), :userinfo_endpoint)

        other ->
          other
      end

    resp = Ueberauth.Strategy.Wordpress.OAuth.get(token, path)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :wordpress_user, user)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", status_code)])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
