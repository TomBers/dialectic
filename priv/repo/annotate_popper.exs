#!/usr/bin/env elixir

# Script to annotate the Popper graph with highlights and links
# This adds highlights to key passages and links them to related nodes

alias Dialectic.Repo
alias Dialectic.Accounts.{User, Graph}
alias Dialectic.Highlights
alias Dialectic.Highlights.{Highlight, HighlightLink}

import Ecto.Query

# Ensure the Repo is started
Application.ensure_all_started(:dialectic)

IO.puts("Loading Popper graph...")

# Get the graph
graph = Repo.get_by!(Graph, title: "Popper: Of Clouds and Clocks - Freedom and Determinism")

IO.puts("Graph found: #{graph.title}")
IO.puts("Slug: #{graph.slug}")
IO.puts("")

# Get or create system user for highlights
user =
  case Repo.get_by(User, email: "system@dialectic.app") do
    nil ->
      IO.puts("Creating system user...")

      {:ok, user} =
        %User{}
        |> User.registration_changeset(%{
          email: "system@dialectic.app",
          username: "system",
          password: SecureRandom.base64(32)
        })
        |> Repo.insert()

      user

    user ->
      IO.puts("Using existing system user: #{user.email}")
      user
  end

IO.puts("")
IO.puts("Graph nodes:")
IO.puts("============")

# Display all nodes with their IDs and content
nodes = graph.data["nodes"] || []

nodes
|> Enum.reject(fn node -> node["compound"] == true end)
|> Enum.each(fn node ->
  IO.puts("\nID: #{node["id"]}")
  IO.puts("Class: #{node["class"]}")
  IO.puts("Content: #{String.slice(node["content"], 0, 100)}...")
end)

IO.puts("")
IO.puts("Creating highlights and links...")
IO.puts("================================")

# Helper function to create a highlight
create_highlight = fn node_id, start_pos, end_pos, text_snapshot, note, linked_nodes ->
  # First check if highlight already exists
  existing =
    Highlights.get_highlight_for_selection(
      graph.title,
      node_id,
      start_pos,
      end_pos
    )

  highlight =
    case existing do
      nil ->
        IO.puts("Creating highlight in node #{node_id}: #{String.slice(text_snapshot, 0, 50)}...")

        {:ok, h} =
          Highlights.create_highlight(%{
            mudg_id: graph.title,
            node_id: node_id,
            text_source_type: "node_content",
            text_source_id: node_id,
            selection_start: start_pos,
            selection_end: end_pos,
            selected_text_snapshot: text_snapshot,
            note: note,
            created_by_user_id: user.id
          })

        h

      h ->
        IO.puts("Highlight already exists in node #{node_id}")
        h
    end

  # Add links to related nodes
  Enum.each(linked_nodes, fn {target_node_id, link_type} ->
    case Highlights.add_link(highlight, target_node_id, link_type) do
      {:ok, _link} ->
        IO.puts("  ✓ Linked to node #{target_node_id} (#{link_type})")

      {:error, %Ecto.Changeset{errors: errors}} ->
        # Check if it's a duplicate error
        case Keyword.get(errors, :highlight_id) do
          {"This highlight is already linked to this node", _} ->
            IO.puts("  → Link already exists for node #{target_node_id}")

          _ ->
            IO.puts("  ✗ Failed to link to node #{target_node_id}: #{inspect(errors)}")
        end

      {:error, reason} ->
        IO.puts("  ✗ Failed to link to node #{target_node_id}: #{inspect(reason)}")
    end
  end)

  highlight
end

# Find node IDs by content matching
find_node_id = fn content_pattern ->
  nodes
  |> Enum.find(fn node ->
    content = node["content"] || ""
    String.contains?(String.downcase(content), String.downcase(content_pattern))
  end)
  |> case do
    nil -> nil
    node -> node["id"]
  end
end

# Now create highlights for key concepts

# 1. Highlight "plastic controls" in the Plastic Controls node
if plastic_controls_id = find_node_id.("plastic controls") do
  node = Enum.find(nodes, fn n -> n["id"] == plastic_controls_id end)
  content = node["content"]

  # Find the key phrase about plastic controls
  if String.contains?(content, "control mechanisms") do
    start_pos = String.length(content) |> div(4)
    end_pos = start_pos + 150

    text =
      String.slice(content, start_pos, 150)
      |> String.trim()

    create_highlight.(
      plastic_controls_id,
      start_pos,
      end_pos,
      text,
      "Core concept: Controls that can be influenced without being rigidly determined",
      [
        {find_node_id.("hierarchical"), "related_idea"},
        {find_node_id.("freedom as rational"), "explain"}
      ]
      |> Enum.reject(fn {id, _} -> is_nil(id) end)
    )
  end
end

# 2. Highlight the cloud-clock spectrum concept
if spectrum_id = find_node_id.("spectrum") do
  node = Enum.find(nodes, fn n -> n["id"] == spectrum_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(200, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    spectrum_id,
    start_pos,
    end_pos,
    text,
    "Central metaphor: physical systems exist on a continuum from disorder to order",
    [
      {find_node_id.("clouds"), "related_idea"},
      {find_node_id.("clocks"), "related_idea"},
      {find_node_id.("laplacian"), "con"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 3. Highlight Compton's Problem
if compton_id = find_node_id.("compton's problem") do
  node = Enum.find(nodes, fn n -> n["id"] == compton_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(250, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    compton_id,
    start_pos,
    end_pos,
    text,
    "The central problem: how can abstract meanings causally influence physical behavior?",
    [
      {find_node_id.("solution to compton"), "explain"},
      {find_node_id.("world 3"), "related_idea"},
      {find_node_id.("argumentative"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 4. Highlight World 3 theory
if world3_id = find_node_id.("world 3") do
  node = Enum.find(nodes, fn n -> n["id"] == world3_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(200, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    world3_id,
    start_pos,
    end_pos,
    text,
    "Popper's three worlds: physical, mental, and objective knowledge",
    [
      {find_node_id.("autonomy"), "explain"},
      {find_node_id.("objective standards"), "related_idea"},
      {find_node_id.("descriptive"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 5. Highlight the argumentative function
if argumentative_id = find_node_id.("argumentative function") do
  node = Enum.find(nodes, fn n -> n["id"] == argumentative_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(180, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    argumentative_id,
    start_pos,
    end_pos,
    text,
    "Highest language function: critical discussion and rational debate (uniquely human)",
    [
      {find_node_id.("rationality as achievement"), "explain"},
      {find_node_id.("theories die"), "related_idea"},
      {find_node_id.("trial and error"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 6. Highlight trial and error elimination
if trial_error_id = find_node_id.("trial and error") do
  node = Enum.find(nodes, fn n -> n["id"] == trial_error_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(200, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    trial_error_id,
    start_pos,
    end_pos,
    text,
    "Universal method of learning: from amoeba to Einstein",
    [
      {find_node_id.("theories die"), "explain"},
      {find_node_id.("emergence"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 7. Highlight downward causation
if downward_id = find_node_id.("downward causation") do
  node = Enum.find(nodes, fn n -> n["id"] == downward_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(200, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    downward_id,
    start_pos,
    end_pos,
    text,
    "Key concept: higher organizational levels can causally influence lower levels",
    [
      {find_node_id.("emergence"), "related_idea"},
      {find_node_id.("hierarchical"), "related_idea"},
      {find_node_id.("anti-reductionism"), "pro"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 8. Highlight the final synthesis
if freedom_id = find_node_id.("freedom as rational self-control") do
  node = Enum.find(nodes, fn n -> n["id"] == freedom_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(250, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    freedom_id,
    start_pos,
    end_pos,
    text,
    "FINAL SYNTHESIS: Freedom emerges from physical plasticity + hierarchical organization + objective knowledge + critical rationality",
    [
      {find_node_id.("plastic controls"), "related_idea"},
      {find_node_id.("hierarchical"), "related_idea"},
      {find_node_id.("world 3"), "related_idea"},
      {find_node_id.("argumentative"), "related_idea"},
      {find_node_id.("solution to compton"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 9. Highlight consciousness role
if consciousness_id = find_node_id.("consciousness") do
  node = Enum.find(nodes, fn n -> n["id"] == consciousness_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(180, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    consciousness_id,
    start_pos,
    end_pos,
    text,
    "Interface between physical and abstract: consciousness enables interaction with World 3",
    [
      {find_node_id.("world 3"), "related_idea"},
      {find_node_id.("descartes"), "related_idea"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

# 10. Highlight emergence
if emergence_id = find_node_id.("emergence") do
  node = Enum.find(nodes, fn n -> n["id"] == emergence_id end)
  content = node["content"]

  start_pos = 0
  end_pos = min(200, String.length(content))

  text =
    String.slice(content, start_pos, end_pos)
    |> String.trim()

  create_highlight.(
    emergence_id,
    start_pos,
    end_pos,
    text,
    "New organizational levels with their own laws emerge from lower levels",
    [
      {find_node_id.("hierarchical"), "related_idea"},
      {find_node_id.("downward causation"), "explain"},
      {find_node_id.("anti-reductionism"), "pro"}
    ]
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
  )
end

IO.puts("")
IO.puts("✓ Highlights and links created successfully!")
IO.puts("")

# Count highlights
highlight_count =
  Highlights.list_highlights(mudg_id: graph.title)
  |> length()

IO.puts("Total highlights: #{highlight_count}")

# Count links
link_count =
  from(hl in HighlightLink,
    join: h in Highlight,
    on: hl.highlight_id == h.id,
    where: h.mudg_id == ^graph.title
  )
  |> Repo.aggregate(:count)

IO.puts("Total highlight links: #{link_count}")

IO.puts("")
IO.puts("View the annotated graph at:")
IO.puts("http://localhost:4000/graph/#{graph.slug}")
