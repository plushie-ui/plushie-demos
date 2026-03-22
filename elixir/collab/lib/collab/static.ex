defmodule Collab.Static do
  @moduledoc false

  # Serve static files from priv/static/.

  @mime_types %{
    ".html" => "text/html; charset=utf-8",
    ".js" => "application/javascript",
    ".mjs" => "application/javascript",
    ".css" => "text/css",
    ".wasm" => "application/wasm",
    ".json" => "application/json",
    ".png" => "image/png",
    ".svg" => "image/svg+xml",
    ".ico" => "image/x-icon"
  }

  defp static_dir do
    :collab
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("static")
  end

  def serve(%Plug.Conn{} = conn) do
    path =
      case conn.path_info do
        [] -> "index.html"
        segments -> Path.join(segments)
      end

    # Prevent path traversal
    if String.contains?(path, "..") do
      Plug.Conn.send_resp(conn, 400, "Bad request")
    else
      file = Path.join(static_dir(), path)

      if File.exists?(file) and not File.dir?(file) do
        content_type = Map.get(@mime_types, Path.extname(file), "application/octet-stream")

        conn
        |> Plug.Conn.put_resp_content_type(content_type)
        |> Plug.Conn.send_file(200, file)
      else
        Plug.Conn.send_resp(conn, 404, "Not found")
      end
    end
  end
end
