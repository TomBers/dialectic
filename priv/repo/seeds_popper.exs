#!/usr/bin/env elixir

# Script for creating Karl Popper's "Of Clouds and Clocks" knowledge graph
#
# Run with: mix run priv/repo/seeds_popper.exs

alias Dialectic.Repo
alias Dialectic.Accounts.{User, Graph}
alias Dialectic.Graph.{Vertex, Serialise}
alias Dialectic.DbActions.Graphs

import Ecto.Query

defmodule PopperGraphBuilder do
  @moduledoc """
  Builds a comprehensive knowledge graph for Karl Popper's essay
  "Of Clouds and Clocks: An Approach to the Problem of Rationality
  and the Freedom of Man"
  """

  def create_graph do
    # Find or create a user
    user = get_or_create_user()

    graph_title = "Popper: Of Clouds and Clocks - Freedom and Determinism"

    # Check if graph already exists
    case Dialectic.DbActions.Graphs.get_graph_by_title(graph_title) do
      nil ->
        IO.puts("Creating new graph: #{graph_title}")
        build_and_save_graph(graph_title, user)

      _existing ->
        IO.puts("Graph already exists: #{graph_title}")
        {:ok, :already_exists}
    end
  end

  defp get_or_create_user do
    # Try to find existing user, or create a test user
    case Repo.get_by(User, email: "system@dialectic.app") do
      nil ->
        IO.puts("Creating system user...")
        {:ok, user} = Dialectic.Accounts.register_user(%{
          email: "system@dialectic.app",
          password: "secure_password_123!",
          username: "system"
        })
        user

      user ->
        IO.puts("Using existing system user")
        user
    end
  end

  defp build_and_save_graph(title, user) do
    # Create the graph structure using :digraph
    graph = :digraph.new([:acyclic])

    # Build all nodes
    nodes = create_nodes()

    # Add all vertices to the graph
    Enum.each(nodes, fn {id, vertex} ->
      :digraph.add_vertex(graph, id, vertex)
    end)

    # Add all edges (relationships between nodes)
    edges = create_edges()
    Enum.each(edges, fn {from_id, to_id} ->
      :digraph.add_edge(graph, from_id, to_id)
    end)

    # Add groups for related concepts
    create_groups(graph)

    # Convert to JSON format
    json_data = Serialise.graph_to_json(graph)

    # Save to database
    token = generate_share_token()
    slug = Graphs.generate_unique_slug(title)

    result = %Graph{}
    |> Graph.changeset(%{
      title: title,
      user_id: user.id,
      data: json_data,
      is_public: true,
      is_locked: false,
      is_deleted: false,
      is_published: true,
      share_token: token,
      slug: slug,
      tags: ["philosophy", "epistemology", "determinism", "free-will", "popper"],
      prompt_mode: "university"
    })
    |> Repo.insert()

    case result do
      {:ok, _graph} ->
        IO.puts("✓ Successfully created graph: #{title}")
        {:ok, title}

      {:error, changeset} ->
        IO.puts("✗ Failed to create graph: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp create_nodes do
    # Origin node - the main essay question
    origin = create_vertex("1", "origin", """
    ## Of Clouds and Clocks

    How can we reconcile physical indeterminism with human freedom and rationality?
    """)

    # Main problems
    compton_problem = create_vertex("2", "question", """
    ## Compton's Problem

    How can abstract meanings and ideas causally influence physical behavior?

    Compton saw this as the central problem of freedom: how can non-physical meanings
    (arguments, reasons, purposes) exert real causal influence on physical events
    (human actions)?
    """)

    descartes_problem = create_vertex("3", "question", """
    ## Descartes's Problem (Mind-Body Problem)

    How can non-physical mind interact with physical body?

    The traditional problem of how mental states can cause physical changes.
    Popper treats this as connected to, but distinct from, Compton's problem.
    """)

    # The Cloud-Clock Spectrum
    spectrum_thesis = create_vertex("4", "thesis", """
    ## The Cloud-Clock Spectrum

    Physical systems exist on a continuum from perfect clouds (completely irregular,
    unpredictable) to perfect clocks (perfectly regular, predictable).

    Most real systems are somewhere in between - they are "cloudlike clocks" with
    varying degrees of regularity and predictability.
    """)

    clouds = create_vertex("5", "premise", """
    ## Clouds (Extreme Indeterminism)

    Highly irregular, disorderly physical systems that are:
    - Unpredictable in detail
    - Composed of countless independent causal chains
    - May show statistical regularities despite individual irregularity

    Examples: weather systems, swarms of gnats, gas molecules
    """)

    clocks = create_vertex("6", "premise", """
    ## Clocks (Extreme Determinism)

    Highly regular, orderly physical systems that are:
    - Predictable with precision
    - Governed by strict causal laws
    - Approaching perfect periodicity

    Examples: solar system, pendulums, atomic clocks
    """)

    # Physical determinism debates
    laplace_determinism = create_vertex("7", "thesis", """
    ## Laplacian Determinism

    The classical view that the universe is like a perfect clock - given complete
    knowledge of present state and laws, we could predict all future states with
    perfect precision.

    "An intellect which at a certain moment would know all forces... and all positions
    of all items... nothing would be uncertain and the future just like the past would
    be present before its eyes." - Laplace
    """)

    determinism_refuted = create_vertex("8", "antithesis", """
    ## Refutation of Pure Determinism

    Modern physics (quantum mechanics, indeterminacy) has shown that:
    - Not all physical events are perfectly predictable
    - There is genuine randomness at quantum level
    - Physical determinism is false

    However, this doesn't solve the freedom problem - mere randomness is not freedom.
    """)

    randomness_insufficient = create_vertex("9", "premise", """
    ## Randomness ≠ Freedom

    Physical indeterminism alone cannot explain human freedom because:
    - Random events are not controlled or rational
    - We need to explain how reasons and purposes influence behavior
    - Freedom requires control, not just lack of determinism

    "It is difficult to see how purely chance decisions could be called 'free'"
    """)

    # The solution - plastic controls and hierarchy
    plastic_controls = create_vertex("10", "answer", """
    ## Plastic Controls

    The key to understanding freedom: controls that can be influenced by abstract
    considerations without being rigidly determined.

    Like a driver steering a car - the control mechanism is sensitive to changing
    conditions and purposes while remaining physically embodied.
    """)

    hierarchical_systems = create_vertex("11", "synthesis", """
    ## Hierarchical Control Systems

    Complex organisms are organized in hierarchies where:
    - Higher levels set goals and constraints
    - Lower levels execute with plasticity
    - Top-down causation operates alongside bottom-up
    - Abstract purposes can influence concrete behavior

    This allows for causal openness - higher-level states can be genuinely influenced
    by considerations, arguments, and meanings.
    """)

    # Evolution of language and its functions
    language_evolution = create_vertex("12", "thesis", """
    ## Evolution of Language Functions

    Language evolved through four main functions, each building on the previous:
    1. Expressive (self-expression)
    2. Signaling (communication)
    3. Descriptive (representing reality)
    4. Argumentative (critical discussion)

    The argumentative function is uniquely human and enables rationality.
    """)

    expressive = create_vertex("13", "premise", """
    ## 1. Expressive Function

    The most basic function: expressing internal states.

    - Present in all animals with any signaling
    - Symptoms of internal conditions
    - Involuntary manifestations

    Example: crying in pain, purring when content
    """)

    signaling = create_vertex("14", "premise", """
    ## 2. Signaling (Communicative) Function

    Evolved to influence others:

    - Release mechanisms that trigger responses in others
    - Can be used to communicate intentionally
    - Still present in human language

    Example: warning calls, mating signals, commands
    """)

    descriptive = create_vertex("15", "premise", """
    ## 3. Descriptive Function

    Representing states of affairs:

    - Can be true or false
    - Allows discussion of absent objects/events
    - Creates a "World 3" of objective content
    - Revolutionary development

    Example: "There is a predator near the waterhole"
    """)

    argumentative = create_vertex("16", "conclusion", """
    ## 4. Argumentative (Critical) Function

    The highest function - critical discussion of descriptions:

    - Enables rational debate
    - Allows theories to die in our stead (trial and error elimination)
    - Creates objective standards of truth
    - Uniquely human

    This is the key to human rationality and freedom: we can critically evaluate
    reasons before acting.
    """)

    # World 3 and objective knowledge
    world3 = create_vertex("17", "thesis", """
    ## World 3: Objective Knowledge

    Three worlds (Popper/Frege):
    - World 1: Physical objects and states
    - World 2: Mental states and consciousness
    - World 3: Objective content of thought (theories, arguments, problems)

    World 3 has autonomous existence once created and can causally influence Worlds 1 & 2.
    """)

    world3_autonomy = create_vertex("18", "premise", """
    ## Autonomy of World 3

    Theories and arguments have consequences independent of anyone thinking them:
    - Mathematical truths existed before discovery
    - Logical implications hold objectively
    - Problems generate new problems
    - Theories can be criticized objectively

    This objective realm can influence human decisions through rational consideration.
    """)

    # Trial and error elimination
    trial_error = create_vertex("19", "answer", """
    ## Trial and Error Elimination Method

    The fundamental method of all life and science:

    Problem → Tentative Solution → Error Elimination → New Problem

    In humans, this becomes rational:
    - We can let our theories die instead of us
    - Critical discussion replaces physical elimination
    - We learn from mistakes without dying from them
    """)

    theories_die = create_vertex("20", "conclusion", """
    ## Theories Die in Our Stead

    Human rationality's great advantage:

    Instead of eliminating wrong behaviors through death/suffering, we can:
    - Propose tentative theories
    - Criticize them through argument
    - Eliminate bad theories before acting on them
    - Learn from the errors of our ideas

    This is genuine learning and progress.
    """)

    # Compton's solution
    compton_solution = create_vertex("21", "answer", """
    ## Solution to Compton's Problem

    How meanings influence behavior:

    1. Descriptive language creates World 3 content
    2. World 3 contains objective arguments and problems
    3. Humans can perceive and evaluate these
    4. Plastic controls allow responsiveness to evaluations
    5. Hierarchical organization enables top-down influence

    Thus abstract meanings genuinely influence concrete actions through rational
    consideration within plastic control systems.
    """)

    # Emergence and downward causation
    emergence = create_vertex("22", "premise", """
    ## Emergence of Higher Levels

    New levels of organization emerge that:
    - Cannot be fully reduced to lower levels
    - Have their own laws and regularities
    - Exert downward causal influence

    Example: Genetic code → Proteins → Cells → Organisms → Behavior
    Each level constrains and enables the level below.
    """)

    downward_causation = create_vertex("23", "synthesis", """
    ## Downward Causation

    Higher-level purposes and considerations can causally influence lower-level
    physical processes:

    - Intentions shape neural activity
    - Arguments change minds and behavior
    - Cultural norms modify individual actions
    - Plans organize material resources

    This is compatible with physical law because:
    - Lower levels are plastically controlled
    - Multiple physical realizations are possible
    - Higher levels select among possibilities
    """)

    # Freedom synthesis
    freedom_synthesis = create_vertex("24", "synthesis", """
    ## Freedom as Rational Self-Control

    Human freedom emerges from:

    1. Physical indeterminism (plasticity at lower levels)
    2. Hierarchical organization (top-down control)
    3. Descriptive language (World 3 access)
    4. Critical discussion (rational evaluation)
    5. Plastic controls (responsiveness to reasons)

    Freedom is not randomness but the capacity for rational self-control through
    critical evaluation of objective arguments.
    """)

    # Additional key concepts
    objective_standards = create_vertex("25", "premise", """
    ## Objective Standards of Rationality

    World 3 provides objective standards independent of subjective belief:
    - Logical validity
    - Empirical truth
    - Coherence and consistency
    - Explanatory power

    These standards can be appealed to in rational debate and guide decision-making.
    """)

    consciousness_role = create_vertex("26", "assumption", """
    ## Role of Consciousness

    Consciousness enables:
    - Awareness of World 3 content
    - Self-monitoring and self-criticism
    - Anticipation of consequences
    - Deliberation among alternatives

    It's the interface between physical embodiment (World 1) and abstract reasoning
    (World 3).
    """)

    anti_reductionism = create_vertex("27", "antithesis", """
    ## Rejection of Reductionism

    Against physicalism/materialism that claims:
    - Only physical causation exists
    - Mental states are "nothing but" brain states
    - Purposes and meanings are epiphenomenal

    Popper argues emergent levels have genuine causal efficacy and cannot be eliminated
    in favor of purely physical description.
    """)

    rationality_achievement = create_vertex("28", "conclusion", """
    ## Rationality as Achievement

    Rationality is not given but achieved through:
    - Learning the argumentative function
    - Participating in critical tradition
    - Submitting to objective standards
    - Developing plastic self-control

    It requires education, culture, and practice - it's a human institution, not
    merely a biological given.
    """)

    Map.new([
      {"1", origin},
      {"2", compton_problem},
      {"3", descartes_problem},
      {"4", spectrum_thesis},
      {"5", clouds},
      {"6", clocks},
      {"7", laplace_determinism},
      {"8", determinism_refuted},
      {"9", randomness_insufficient},
      {"10", plastic_controls},
      {"11", hierarchical_systems},
      {"12", language_evolution},
      {"13", expressive},
      {"14", signaling},
      {"15", descriptive},
      {"16", argumentative},
      {"17", world3},
      {"18", world3_autonomy},
      {"19", trial_error},
      {"20", theories_die},
      {"21", compton_solution},
      {"22", emergence},
      {"23", downward_causation},
      {"24", freedom_synthesis},
      {"25", objective_standards},
      {"26", consciousness_role},
      {"27", anti_reductionism},
      {"28", rationality_achievement}
    ])
  end

  defp create_vertex(id, class, content) do
    %Vertex{
      id: id,
      content: String.trim(content),
      class: class,
      user: "system",
      parent: nil,
      noted_by: [],
      deleted: false,
      compound: false
    }
  end

  defp create_edges do
    [
      # Origin connects to main problems
      {"1", "2"},  # Origin → Compton's Problem
      {"1", "3"},  # Origin → Descartes's Problem
      {"1", "4"},  # Origin → Cloud-Clock Spectrum

      # Cloud-Clock spectrum development
      {"4", "5"},  # Spectrum → Clouds
      {"4", "6"},  # Spectrum → Clocks
      {"4", "7"},  # Spectrum → Laplacian Determinism

      # Determinism debate
      {"7", "8"},  # Laplacian Determinism → Refutation
      {"8", "9"},  # Refutation → Randomness Insufficient

      # Path to solution
      {"9", "10"},  # Randomness Insufficient → Plastic Controls
      {"10", "11"}, # Plastic Controls → Hierarchical Systems

      # Language evolution chain
      {"1", "12"},  # Origin → Language Evolution
      {"12", "13"}, # Language Evolution → Expressive
      {"13", "14"}, # Expressive → Signaling
      {"14", "15"}, # Signaling → Descriptive
      {"15", "16"}, # Descriptive → Argumentative

      # World 3 development
      {"15", "17"}, # Descriptive → World 3
      {"17", "18"}, # World 3 → Autonomy
      {"18", "25"}, # Autonomy → Objective Standards

      # Trial and error method
      {"16", "19"}, # Argumentative → Trial/Error
      {"19", "20"}, # Trial/Error → Theories Die

      # Emergence and causation
      {"11", "22"}, # Hierarchical Systems → Emergence
      {"22", "23"}, # Emergence → Downward Causation

      # Solution to Compton's problem
      {"2", "21"},  # Compton's Problem → Solution
      {"16", "21"}, # Argumentative → Solution
      {"10", "21"}, # Plastic Controls → Solution
      {"11", "21"}, # Hierarchical Systems → Solution
      {"17", "21"}, # World 3 → Solution

      # Final synthesis
      {"21", "24"}, # Solution → Freedom Synthesis
      {"23", "24"}, # Downward Causation → Freedom Synthesis
      {"20", "24"}, # Theories Die → Freedom Synthesis

      # Supporting connections
      {"16", "26"}, # Argumentative → Consciousness Role
      {"26", "24"}, # Consciousness → Freedom Synthesis
      {"7", "27"},  # Laplacian Determinism → Anti-Reductionism
      {"27", "23"}, # Anti-Reductionism → Downward Causation
      {"16", "28"}, # Argumentative → Rationality Achievement
      {"25", "28"}  # Objective Standards → Rationality Achievement
    ]
  end

  defp create_groups(graph) do
    # Group related concepts together for better visualization

    # Problems group
    problems = ["2", "3"]
    Dialectic.Graph.Vertex.add_group(graph, "problems", problems)

    # Cloud-Clock Spectrum group
    spectrum = ["5", "6", "7"]
    Dialectic.Graph.Vertex.add_group(graph, "cloud-clock-spectrum", spectrum)

    # Determinism Debate group
    determinism = ["8", "9"]
    Dialectic.Graph.Vertex.add_group(graph, "determinism-debate", determinism)

    # Control Mechanisms group
    controls = ["10", "11"]
    Dialectic.Graph.Vertex.add_group(graph, "control-mechanisms", controls)

    # Language Functions group
    language = ["13", "14", "15", "16"]
    Dialectic.Graph.Vertex.add_group(graph, "language-evolution", language)

    # World 3 group
    world3 = ["17", "18", "25"]
    Dialectic.Graph.Vertex.add_group(graph, "world3-knowledge", world3)

    # Learning Method group
    learning = ["19", "20"]
    Dialectic.Graph.Vertex.add_group(graph, "learning-method", learning)

    # Causation group
    causation = ["22", "23", "27"]
    Dialectic.Graph.Vertex.add_group(graph, "emergence-causation", causation)

    # Final Synthesis group
    synthesis = ["24", "26", "28"]
    Dialectic.Graph.Vertex.add_group(graph, "freedom-synthesis", synthesis)

    graph
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end

# Run the graph creation
case PopperGraphBuilder.create_graph() do
  {:ok, title} ->
    IO.puts("\n✓ Successfully created graph: #{title}")
    IO.puts("You can now view it at: /graph/<slug-or-title>")

  {:ok, :already_exists} ->
    IO.puts("\nGraph already exists. Delete it first if you want to recreate it.")

  {:error, reason} ->
    IO.puts("\n✗ Failed to create graph: #{inspect(reason)}")
    System.halt(1)
end
