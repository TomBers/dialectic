defmodule Mix.Tasks.Assets.CopyKatexFonts do
  use Mix.Task

  @shortdoc "Copies KaTeX font assets into priv/static/assets/fonts"

  @impl Mix.Task
  def run(_args) do
    source_dir = Path.expand("assets/node_modules/katex/dist/fonts", File.cwd!())
    target_dir = Path.expand("priv/static/assets/fonts", File.cwd!())

    unless File.dir?(source_dir) do
      Mix.raise("""
      KaTeX fonts not found at #{source_dir}.

      Run `npm install` in `assets/` before building assets.
      """)
    end

    File.cp!(
      Path.join(Path.dirname(source_dir), "katex.min.css"),
      Path.join(Path.dirname(target_dir), "katex.css")
    )

    File.rm_rf!(target_dir)
    File.mkdir_p!(target_dir)

    source_dir
    |> File.ls!()
    |> Enum.each(fn file_name ->
      File.cp!(Path.join(source_dir, file_name), Path.join(target_dir, file_name))
    end)
  end
end
