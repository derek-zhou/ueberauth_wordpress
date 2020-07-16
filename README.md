# Ueberauth Wordpress

Wordpress OAuth2 strategy for Überauth.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ueberauth_wordpress` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ueberauth_wordpress, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ueberauth_wordpress](https://hexdocs.pm/ueberauth_wordpress).

The code is mostly lifted from similiar OAuth2 strategies for Überauth on github, and tailored for wordpress. You need to get your `client_id` and `client_secret` from: [wordpress](https://developer.wordpress.com/)

Then config your application with:

```slixir
config :ueberauth, Ueberauth,
  providers: [
    wordpress: {Ueberauth.Strategy.Wordpress, [default_scope: "auth"]}
  ]
  
config :ueberauth, Ueberauth.Strategy.Wordpress.OAuth,
  client_id: System.get_env("WORDPRESS_CLIENT_ID"),
  client_secret: System.get_env("WORDPRESS_CLIENT_SECRET")
```

## Calling

Depending on the configured url you can initiate the request through:

    /auth/wordpress?state=RANDOMSTRING

Please note wordpress demands a state parameter. The strategy right now does not make use of it or check it, nevertheless, you need to pass something in.

Another thing specific to wordpress is that it cannot have `redirect_uri` pre-configured, and has to take a value from the parameter. You need to make sure your app has its url configured correctly with the public facing URL. 

## License

This software is released under the MIT license. Please refer to the LICENSE file for detail.

