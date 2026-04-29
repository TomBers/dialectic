# Graph Extraction for Image Generation

This module provides functionality to extract graphs from the database into a concise, minimal format suitable for passing to image generation tools.

## Overview

The `Dialectic.Graph.Extractor` module takes complex graph structures stored in the database and distills them into a clean, minimal representation that contains only the essential information needed to visualize the graph structure.

**✨ Available via UI:** You can now download the extracted JSON directly from any graph using the Export menu alongside PNG and Markdown downloads!

### What it extracts:

- **Nodes**: ID, content, type (class), and parent/compound information
- **Edges**: Simple from/to relationships

### What it filters out:

- Deleted nodes
- User metadata
- Timestamps
- Internal bookkeeping fields (`noted_by`, `source_text`, etc.)
- Edges pointing to deleted/non-existent nodes

## Quick Start

### Programmatic Usage

```elixir
alias Dialectic.Graph.Extractor

# Extract by title
{:ok, data} = Extractor.extract_for_image_generation("My Graph Title")

# Extract by slug
{:ok, data} = Extractor.extract_for_image_generation("my-graph-slug-abc123")

# Extract to JSON
{:ok, json} = Extractor.extract_to_json("My Graph Title")
File.write!("graph.json", json)
```

### UI Download

1. Open any graph in the application
2. Click the **Export** dropdown menu
3. Select **JSON** to download the extracted graph data

The download will respect access permissions (public/private graphs, share tokens, etc.)

### API Endpoint

```bash
# Download by slug
curl https://your-app.com/api/graphs/json/my-graph-slug-abc123 -o graph.json

# Download private graph with share token
curl "https://your-app.com/api/graphs/json/my-graph?token=YOUR_TOKEN" -o graph.json
```

## Output Format

### Structure

```elixir
%{
  nodes: [
    %{id: "1", content: "Question text", class: "question"},
    %{id: "2", content: "Answer text", class: "answer"},
    %{id: "group-1", content: "", class: "", compound: true},
    %{id: "3", content: "Grouped node", class: "thesis", parent: "group-1"}
  ],
  edges: [
    %{from: "1", to: "2"},
    %{from: "2", to: "3"}
  ]
}
```

### JSON Example

```json
{
  "nodes": [
    {
      "id": "1",
      "content": "What is consciousness?",
      "class": "question"
    },
    {
      "id": "2",
      "content": "Consciousness is awareness of one's surroundings",
      "class": "answer"
    }
  ],
  "edges": [
    {
      "from": "1",
      "to": "2"
    }
  ]
}
```

### Field Reference

#### Node Fields

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `id` | string | Unique node identifier | Yes |
| `content` | string | Node text content | Yes |
| `class` | string | Node type (question, answer, thesis, etc.) | Yes |
| `parent` | string | Parent group ID (for grouped nodes) | Optional |
| `compound` | boolean | Marks group/container nodes | Optional |

#### Edge Fields

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `from` | string | Source node ID | Yes |
| `to` | string | Target node ID | Yes |

#### Node Classes

Common node classes in the system:
- `question` - Questions posed in the graph
- `answer` - Direct answers to questions
- `thesis` - Thesis statements
- `antithesis` - Counter-arguments
- `synthesis` - Synthesis of thesis/antithesis
- `origin` - Root/starting nodes
- `premise` - Logical premises
- `conclusion` - Logical conclusions
- `assumption` - Assumptions
- `deepdive` - Deep dive explorations
- `user` - User-contributed content

## API Reference

### Module Functions

#### `extract_for_image_generation/1`

Extracts a graph into minimal format.

```elixir
# With Graph struct
graph = Dialectic.DbActions.Graphs.get_graph_by_title("My Graph")
data = Extractor.extract_for_image_generation(graph)

# With string identifier (title or slug)
{:ok, data} = Extractor.extract_for_image_generation("My Graph")
{:error, :not_found} = Extractor.extract_for_image_generation("non-existent")
```

**Returns:**
- When given a `%Graph{}` struct: returns the extracted map directly
- When given a string: returns `{:ok, data}` or `{:error, :not_found}`

#### `extract_to_json/1`

Extracts to pretty-printed JSON string.

```elixir
# With Graph struct
graph = Dialectic.DbActions.Graphs.get_graph_by_title("My Graph")
json_string = Extractor.extract_to_json(graph)

# With string identifier
{:ok, json_string} = Extractor.extract_to_json("My Graph")
{:error, :not_found} = Extractor.extract_to_json("non-existent")
```

**Returns:**
- When given a `%Graph{}` struct: returns JSON string directly
- When given a string: returns `{:ok, json_string}` or `{:error, :not_found}`

#### `extract_to_compact_json/1`

Extracts to compact JSON (no extra whitespace).

```elixir
{:ok, compact} = Extractor.extract_to_compact_json("My Graph")
```

Same return pattern as `extract_to_json/1` but without pretty-printing.

### HTTP Endpoint

```
GET /api/graphs/json/:graph_name
```

**Parameters:**
- `:graph_name` - Graph slug or title (URL-encoded if using title)
- `token` (query parameter, optional) - Share token for accessing private graphs

**Response Headers:**
- `Content-Type: application/json; charset=utf-8`
- `Content-Disposition: attachment; filename="graph-slug.json"`

**Response Codes:**
- `200 OK` - Returns extracted JSON
- `403 Forbidden` - User lacks permission to access graph
- `404 Not Found` - Graph does not exist

**Access Control:**
The endpoint respects the same access control as the web interface:
- Public graphs are accessible to anyone
- Private graphs require authentication as owner OR valid share token
- Share invitations are respected

**Examples:**

```bash
# Download public graph
curl https://app.com/api/graphs/json/my-graph-slug-abc123 \
  -o graph.json

# Download private graph with authentication cookie
curl https://app.com/api/graphs/json/private-graph \
  -H "Cookie: _dialectic_web_key=..." \
  -o graph.json

# Download private graph with share token
curl "https://app.com/api/graphs/json/private-graph?token=SHARE_TOKEN" \
  -o graph.json

# Using wget
wget https://app.com/api/graphs/json/my-graph-slug-abc123
```

## Usage Examples

### Example 1: Save Graph for External Tool

```elixir
alias Dialectic.Graph.Extractor

def export_graph_for_visualization(graph_title) do
  case Extractor.extract_to_json(graph_title) do
    {:ok, json} ->
      File.write!("exports/#{graph_title}.json", json)
      {:ok, "Graph exported successfully"}
    
    {:error, :not_found} ->
      {:error, "Graph not found"}
  end
end
```

### Example 2: Send to Image Generation API

```elixir
defmodule MyApp.ImageGenerator do
  alias Dialectic.Graph.Extractor
  
  def generate_image(graph_title) do
    with {:ok, json} <- Extractor.extract_to_compact_json(graph_title),
         {:ok, response} <- send_to_api(json) do
      {:ok, response.body["image_url"]}
    end
  end
  
  defp send_to_api(json_data) do
    Req.post("https://api.image-gen.com/graph",
      json: Jason.decode!(json_data),
      headers: [{"Authorization", "Bearer #{api_key()}"}]
    )
  end
  
  defp api_key, do: Application.get_env(:my_app, :image_gen_api_key)
end
```

### Example 3: LiveView Integration

```elixir
defmodule MyAppWeb.GraphLive do
  use MyAppWeb, :live_view
  alias Dialectic.Graph.Extractor
  
  def handle_event("export_for_visualization", %{"title" => title}, socket) do
    case Extractor.extract_for_image_generation(title) do
      {:ok, data} ->
        # Send to JS hook for visualization
        {:noreply, push_event(socket, "render_graph", %{data: data})}
      
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Graph not found")}
    end
  end
end
```

### Example 4: Batch Export

```elixir
defmodule MyApp.BatchExporter do
  alias Dialectic.Graph.Extractor
  alias Dialectic.DbActions.Graphs
  
  def export_all_public_graphs(output_dir \\ "exports") do
    File.mkdir_p!(output_dir)
    
    Graphs.list_graphs()
    |> Enum.filter(& &1.is_public)
    |> Enum.each(fn graph ->
      json = Extractor.extract_to_json(graph)
      filename = "#{output_dir}/#{graph.slug}.json"
      File.write!(filename, json)
    end)
  end
end
```

### Example 5: Build AI Prompt from Extracted Data

```elixir
defmodule MyApp.PromptBuilder do
  alias Dialectic.Graph.Extractor
  
  def build_visualization_prompt(graph_title) do
    {:ok, data} = Extractor.extract_for_image_generation(graph_title)
    
    node_count = length(data.nodes)
    edge_count = length(data.edges)
    
    node_types = 
      data.nodes
      |> Enum.map(& &1.class)
      |> Enum.uniq()
      |> Enum.join(", ")
    
    """
    Create a beautiful visualization of a knowledge graph with:
    - #{node_count} nodes of types: #{node_types}
    - #{edge_count} connections between ideas
    - Modern, clean design with good spacing
    - Clear hierarchical layout
    - Professional color scheme
    
    The graph explores: #{get_main_topic(data)}
    """
  end
  
  defp get_main_topic(data) do
    # Get content from the first origin or question node
    data.nodes
    |> Enum.find(fn n -> n.class in ["origin", "question"] end)
    |> case do
      nil -> "various topics"
      node -> node.content
    end
  end
end
```

## Integration with Visualization Tools

The extracted format is compatible with many popular graph visualization libraries:

### Cytoscape.js

Already used in the app. The format can be adapted with minor transformation:

```javascript
// Transform extracted format to Cytoscape format
const cytoscapeElements = {
  nodes: extractedData.nodes.map(n => ({
    data: { id: n.id, label: n.content, type: n.class }
  })),
  edges: extractedData.edges.map(e => ({
    data: { source: e.from, target: e.to }
  }))
};
```

### D3.js

```javascript
// D3 force-directed graph
const simulation = d3.forceSimulation(extractedData.nodes)
  .force("link", d3.forceLink(extractedData.edges)
    .id(d => d.id))
  .force("charge", d3.forceManyBody())
  .force("center", d3.forceCenter(width / 2, height / 2));
```

### Graphviz DOT Format

```elixir
defmodule MyApp.DotConverter do
  def to_dot(extracted_data) do
    nodes = Enum.map(extracted_data.nodes, fn n ->
      ~s(  "#{n.id}" [label="#{escape(n.content)}" shape=box];)
    end)
    
    edges = Enum.map(extracted_data.edges, fn e ->
      ~s(  "#{e.from}" -> "#{e.to}";)
    end)
    
    """
    digraph G {
      rankdir=TB;
    #{Enum.join(nodes, "\n")}
    #{Enum.join(edges, "\n")}
    }
    """
  end
  
  defp escape(text), do: String.replace(text, "\"", "\\\"")
end
```

## Testing

### Run Extraction Module Tests

```bash
mix test test/graph/extractor_test.exs
```

### Run API Endpoint Tests

```bash
mix test test/dialectic_web/controllers/page_controller_json_extract_test.exs
```

### Run Demo Script

```bash
mix run lib/dialectic/graph/extractor_demo.exs
```

### Test Coverage

The test suite includes:
- Basic extraction with nodes and edges
- Filtering deleted nodes
- Grouped nodes with parent relationships
- Compound nodes
- Empty graphs
- Edge filtering (invalid source/target)
- Access control (public/private graphs)
- Share token validation
- Filename sanitization

## Performance Considerations

- **Fast extraction**: Operates on in-memory data structures
- **No additional queries**: When passing `%Graph{}` struct directly
- **JSON encoding**: Main performance factor for large graphs
- **Caching**: Consider caching extracted JSON for frequently accessed graphs

For very large graphs (>1000 nodes), the extraction typically takes <100ms.

## Security

The extraction endpoint follows the same security model as the rest of the application:

- **Access control**: Respects public/private graph settings
- **Authentication**: Private graphs require authentication
- **Share tokens**: Validated using secure comparison
- **Filename sanitization**: Prevents path traversal attacks
- **No sensitive data**: Filters out user information and metadata

## Related Files

### Core Module
- `lib/dialectic/graph/extractor.ex` - Main extraction logic

### HTTP Interface
- `lib/dialectic_web/controllers/page_controller.ex` - `graph_json_extract/2` action
- `lib/dialectic_web/router.ex` - Route definition

### UI Components
- `lib/dialectic_web/live/export_menu_comp.ex` - Export dropdown menu
- `lib/dialectic_web/live/right_panel_comp.ex` - Right panel export section
- `lib/dialectic_web/live/note_menu_comp.ex` - Note menu export buttons

### Tests
- `test/graph/extractor_test.exs` - Module tests (14 tests)
- `test/dialectic_web/controllers/page_controller_json_extract_test.exs` - Endpoint tests (13 tests)

### Documentation
- `lib/dialectic/graph/extractor_demo.exs` - Interactive demo script
- `lib/dialectic/graph/EXTRACTION_README.md` - This file

## Future Enhancements

Potential improvements for this module:

1. **Format adapters** - Direct conversion to Graphviz DOT, Mermaid, etc.
2. **Filtering options** - Extract subgraphs by node type or depth
3. **Metadata inclusion** - Optional fields like timestamps, authors
4. **Compression** - Automatic compression for large graphs
5. **Streaming** - Stream large graphs to avoid memory issues
6. **Batch export API** - Export multiple graphs in one request
7. **Webhook integration** - Trigger exports on graph updates

## Contributing

When adding new features:

1. Update the extractor module (`extractor.ex`)
2. Add tests to `test/graph/extractor_test.exs`
3. Update endpoint tests if changing API behavior
4. Update this README
5. Update the module documentation
6. Add UI tests for download buttons if needed

## License

This module is part of the Dialectic project and follows the same license.