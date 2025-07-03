defmodule DialecticWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use DialecticWeb, :html

  embed_templates "page_html/*"

  def gen_link(graph, node \\ nil) do
    case node do
      nil -> ~p"/#{URI.encode(graph)}"
      _ -> ~p"/#{URI.encode(graph)}?node=#{node}"
    end
  end
end
