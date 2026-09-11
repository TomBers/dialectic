defmodule Dialectic.Repo.Migrations.AlignReadingFontDefault do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :reading_font, :string,
        default: "serif",
        null: false,
        from: {:string, default: "sans", null: false}
    end
  end
end
