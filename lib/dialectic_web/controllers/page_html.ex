defmodule DialecticWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use DialecticWeb, :html

  embed_templates "page_html/*"

  def gen_link(graph, node \\ nil) do
    case node do
      nil -> ~p"/#{URI.encode(graph, &URI.char_unreserved?/1)}"
      _ -> ~p"/#{URI.encode(graph, &URI.char_unreserved?/1)}?node=#{node}"
    end
  end
end
