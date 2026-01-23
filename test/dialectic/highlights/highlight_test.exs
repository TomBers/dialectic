defmodule Dialectic.Highlights.HighlightTest do
  use Dialectic.DataCase, async: true
  alias Dialectic.Highlights.Highlight
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Accounts.User

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "test text",
        created_by_user_id: 1
      }

      changeset = Highlight.changeset(%Highlight{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset when required fields are missing" do
      changeset = Highlight.changeset(%Highlight{}, %{})
      refute changeset.valid?

      assert %{
               mudg_id: ["can't be blank"],
               node_id: ["can't be blank"],
               text_source_type: ["can't be blank"],
               selection_start: ["can't be blank"],
               selection_end: ["can't be blank"],
               selected_text_snapshot: ["can't be blank"],
               created_by_user_id: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates selection_start is non-negative" do
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: -1,
        selection_end: 10,
        selected_text_snapshot: "test text",
        created_by_user_id: 1
      }

      changeset = Highlight.changeset(%Highlight{}, attrs)
      refute changeset.valid?
      assert %{selection_start: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "validates selection_end is non-negative" do
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: -5,
        selected_text_snapshot: "test text",
        created_by_user_id: 1
      }

      changeset = Highlight.changeset(%Highlight{}, attrs)
      refute changeset.valid?
      errors = errors_on(changeset)
      assert "must be greater than or equal to 0" in errors.selection_end
    end

    test "validates selection_end is greater than selection_start" do
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 10,
        selection_end: 10,
        selected_text_snapshot: "test text",
        created_by_user_id: 1
      }

      changeset = Highlight.changeset(%Highlight{}, attrs)
      refute changeset.valid?
      assert %{selection_end: ["must be greater than selection_start"]} = errors_on(changeset)
    end

    test "validates selection_end is greater than selection_start when end is less" do
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 15,
        selection_end: 10,
        selected_text_snapshot: "test text",
        created_by_user_id: 1
      }

      changeset = Highlight.changeset(%Highlight{}, attrs)
      refute changeset.valid?
      assert %{selection_end: ["must be greater than selection_start"]} = errors_on(changeset)
    end
  end

  describe "validate_no_overlap/1 - creating non-overlapping highlights" do
    setup do
      # Create a user fixture
      user =
        Repo.insert!(%User{
          email: "test@example.com",
          hashed_password: "hashed"
        })

      # Create a graph fixture
      graph =
        Repo.insert!(%Graph{
          title: "test_graph",
          data: %{},
          user_id: user.id
        })

      {:ok, user: user, graph: graph}
    end

    test "allows creating non-overlapping highlights on the same node", %{user: user} do
      # Create first highlight (positions 0-10)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "first text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Create second non-overlapping highlight (positions 20-30)
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 20,
        selection_end: 30,
        selected_text_snapshot: "second text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      assert changeset.valid?
      assert {:ok, _second_highlight} = Repo.insert(changeset)
    end

    test "allows adjacent highlights (end of one equals start of another)", %{user: user} do
      # Create first highlight (positions 0-10)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "first text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Create adjacent highlight (positions 10-20)
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 10,
        selection_end: 20,
        selected_text_snapshot: "second text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      assert changeset.valid?
      assert {:ok, _second_highlight} = Repo.insert(changeset)
    end

    test "allows highlights on different nodes with same positions", %{user: user} do
      # Create highlight on first node
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Create highlight on different node with same positions
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_456",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      assert changeset.valid?
      assert {:ok, _second_highlight} = Repo.insert(changeset)
    end

    test "allows highlights on different graphs with same node and positions", %{user: user} do
      # Create first graph
      graph1 =
        Repo.insert!(%Graph{
          title: "graph_1",
          data: %{},
          user_id: user.id
        })

      # Create second graph
      graph2 =
        Repo.insert!(%Graph{
          title: "graph_2",
          data: %{},
          user_id: user.id
        })

      # Create highlight on first graph
      first_attrs = %{
        mudg_id: graph1.title,
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Create highlight on different graph
      second_attrs = %{
        mudg_id: graph2.title,
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      assert changeset.valid?
      assert {:ok, _second_highlight} = Repo.insert(changeset)
    end
  end

  describe "validate_no_overlap/1 - preventing overlapping highlights" do
    setup do
      # Create a user fixture
      user =
        Repo.insert!(%User{
          email: "test@example.com",
          hashed_password: "hashed"
        })

      # Create a graph fixture
      graph =
        Repo.insert!(%Graph{
          title: "test_graph",
          data: %{},
          user_id: user.id
        })

      {:ok, user: user, graph: graph}
    end

    test "prevents creating exact duplicate highlight", %{user: user} do
      # Create first highlight
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "test text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(attrs)
        |> Repo.insert()

      # Try to create exact duplicate
      changeset = Highlight.changeset(%Highlight{}, attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end

    test "prevents creating overlapping highlight (new contains existing)", %{user: user} do
      # Create first highlight (positions 5-15)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 5,
        selection_end: 15,
        selected_text_snapshot: "middle text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Try to create overlapping highlight that contains the first (positions 0-20)
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 20,
        selected_text_snapshot: "larger text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end

    test "prevents creating overlapping highlight (existing contains new)", %{user: user} do
      # Create first highlight (positions 0-20)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 20,
        selected_text_snapshot: "large text",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Try to create overlapping highlight contained within the first (positions 5-15)
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 5,
        selection_end: 15,
        selected_text_snapshot: "small text",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end

    test "prevents creating overlapping highlight (partial overlap at start)", %{user: user} do
      # Create first highlight (positions 10-20)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 10,
        selection_end: 20,
        selected_text_snapshot: "second half",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Try to create overlapping highlight (positions 5-15) - overlaps at start
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 5,
        selection_end: 15,
        selected_text_snapshot: "overlapping",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end

    test "prevents creating overlapping highlight (partial overlap at end)", %{user: user} do
      # Create first highlight (positions 0-10)
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "first half",
        created_by_user_id: user.id
      }

      {:ok, _first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      # Try to create overlapping highlight (positions 5-15) - overlaps at end
      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 5,
        selection_end: 15,
        selected_text_snapshot: "overlapping",
        created_by_user_id: user.id
      }

      changeset = Highlight.changeset(%Highlight{}, second_attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end
  end

  describe "validate_no_overlap/1 - updating highlights" do
    setup do
      # Create a user fixture
      user =
        Repo.insert!(%User{
          email: "test@example.com",
          hashed_password: "hashed"
        })

      # Create a graph fixture
      graph =
        Repo.insert!(%Graph{
          title: "test_graph",
          data: %{},
          user_id: user.id
        })

      {:ok, user: user, graph: graph}
    end

    test "allows updating a highlight to not overlap with others", %{user: user} do
      # Create two non-overlapping highlights
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "first",
        created_by_user_id: user.id
      }

      {:ok, first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 20,
        selection_end: 30,
        selected_text_snapshot: "second",
        created_by_user_id: user.id
      }

      {:ok, _second_highlight} =
        %Highlight{}
        |> Highlight.changeset(second_attrs)
        |> Repo.insert()

      # Update first highlight to non-overlapping position (40-50)
      update_attrs = %{
        selection_start: 40,
        selection_end: 50
      }

      changeset = Highlight.changeset(first_highlight, update_attrs)
      assert changeset.valid?
      assert {:ok, _updated} = Repo.update(changeset)
    end

    test "prevents updating a highlight to overlap with another", %{user: user} do
      # Create two non-overlapping highlights
      first_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "first",
        created_by_user_id: user.id
      }

      {:ok, first_highlight} =
        %Highlight{}
        |> Highlight.changeset(first_attrs)
        |> Repo.insert()

      second_attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 20,
        selection_end: 30,
        selected_text_snapshot: "second",
        created_by_user_id: user.id
      }

      {:ok, _second_highlight} =
        %Highlight{}
        |> Highlight.changeset(second_attrs)
        |> Repo.insert()

      # Try to update first highlight to overlap with second (15-25)
      update_attrs = %{
        selection_start: 15,
        selection_end: 25
      }

      changeset = Highlight.changeset(first_highlight, update_attrs)
      refute changeset.valid?

      assert %{
               selection_start: [
                 "A highlight already exists that overlaps with this text selection"
               ]
             } = errors_on(changeset)
    end

    test "allows updating a highlight's own position (doesn't compare to itself)", %{user: user} do
      # Create a highlight
      attrs = %{
        mudg_id: "test_graph",
        node_id: "node_123",
        text_source_type: "node_content",
        selection_start: 0,
        selection_end: 10,
        selected_text_snapshot: "original",
        created_by_user_id: user.id
      }

      {:ok, highlight} =
        %Highlight{}
        |> Highlight.changeset(attrs)
        |> Repo.insert()

      # Update the highlight's position
      update_attrs = %{
        selection_start: 5,
        selection_end: 15
      }

      changeset = Highlight.changeset(highlight, update_attrs)
      assert changeset.valid?
      assert {:ok, _updated} = Repo.update(changeset)
    end
  end
end
