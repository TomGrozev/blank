defmodule DemoAppWeb.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>DemoApp</title>
    </head>
    <body>
      <h1>Welcome to DemoApp</h1>
      <p><a href="/admin">Go to Admin Panel</a></p>
    </body>
    </html>
    """)
  end
end
