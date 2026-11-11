defmodule DialecticWeb.StaticAssetsTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias DialecticWeb.StaticAssets

  @immutable "public, max-age=31536000, immutable"

  @tag :tmp_dir
  test "fingerprinted assets keep immutable caching on GET, HEAD and revalidation", %{
    tmp_dir: dir
  } do
    paths = [
      "/assets/chunks/graph_hook-AB12CD34.js",
      "/assets/app-0123456789abcdef0123456789abcdef.css",
      "/images/hero-0123456789abcdef0123456789abcdef.webp",
      "/assets/fonts/math-0123456789abcdef0123456789abcdef.woff2"
    ]

    opts = StaticAssets.init(at: "/", from: dir, gzip: true)

    for path <- paths do
      file = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, "asset")
      File.write!(file <> ".gz", :zlib.gzip("asset"))
      response = StaticAssets.call(conn(:get, path), opts)
      assert response.status == 200
      assert get_resp_header(response, "cache-control") == [@immutable]

      head = StaticAssets.call(conn(:head, path), opts)
      assert head.status == 200
      assert get_resp_header(head, "cache-control") == [@immutable]

      [etag] = get_resp_header(response, "etag")
      fresh = conn(:get, path) |> put_req_header("if-none-match", etag) |> StaticAssets.call(opts)
      assert fresh.status == 304
      assert get_resp_header(fresh, "cache-control") == [@immutable]

      compressed =
        conn(:get, path) |> put_req_header("accept-encoding", "gzip") |> StaticAssets.call(opts)

      assert get_resp_header(compressed, "content-encoding") == ["gzip"]
      assert get_resp_header(compressed, "cache-control") == [@immutable]
    end
  end

  @tag :tmp_dir
  test "editable assets, uploads and documents do not get immutable caching", %{tmp_dir: dir} do
    opts = StaticAssets.init(at: "/", from: dir)

    for path <- [
          "/assets/app.css",
          "/assets/katex.css",
          "/assets/app.js",
          "/images/hero.webp",
          "/uploads/private-0123456789abcdef0123456789abcdef.png",
          "/index.html"
        ] do
      file = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, "editable")
      response = StaticAssets.call(conn(:get, path), opts)
      assert get_resp_header(response, "cache-control") == ["public"]
    end

    request = conn(:get, "/assets/chunks/missing-AB12CD34.js")
    missing = StaticAssets.call(request, opts)
    refute missing.halted
    assert get_resp_header(missing, "cache-control") == get_resp_header(request, "cache-control")
  end
end
