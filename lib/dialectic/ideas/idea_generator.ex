defmodule Dialectic.Ideas.IdeaGenerator do
  @moduledoc """
  A simple idea generator that creates interesting questions based on a given topic.
  """

  # List of question templates with a {topic} placeholder.
  @templates [
    "Let's talk about {topic}.",
    "What is the philosophy of {topic}?",
    "How does {topic} challenge our conventional thinking?",
    "In what ways can we explore the meta-rationality of {topic}?",
    "What is the deeper meaning behind {topic}?",
    "Could you elaborate on the complexities of {topic}?",
    "How does {topic} connect to contemporary debates?",
    "What if we viewed {topic} from an unconventional perspective?"
  ]

  @topics [
    "Meta-rationality",
    "Blood Meridian",
    "Existentialism",
    "Quantum Mechanics",
    "Artificial Intelligence",
    "Cybernetics",
    "Postmodernism",
    "Phenomenology",
    "Absurdism",
    "Deep Ecology",
    "Chaos Theory",
    "Epistemology",
    "Cryptography",
    "Semiotics",
    "Futurism",
    "Dystopian Literature",
    "Solipsism",
    "Transhumanism",
    "Virtual Reality",
    "Social Constructivism",
    "Interdisciplinary Research",
    "Emergent Behavior",
    "Ontology",
    "Fractal Geometry",
    "Neural Networks",
    "Simulation Theory",
    "Game Theory",
    "Biopolitics",
    "Cyberpunk",
    "Existential Risk",
    "Posthumanism",
    "Speculative Realism",
    "New Materialism",
    "Anthropocene",
    "Cognitive Science",
    "Complex Systems",
    "Artificial Consciousness",
    "Economic Philosophy",
    "Digital Humanities",
    "Aesthetics in the Digital Age",
    "Structuralism",
    "Romanticism",
    "Gothic Literature",
    "Modernist Literature",
    "Literary Criticism",
    "Philosophy of Science",
    "Evolutionary Psychology",
    "Moral Philosophy",
    "Spirituality in Modern Life",
    "Philosophy of Technology",
    "Post-structuralism",
    "Neo-noir cinema",
    "Digital art and NFTs",
    "Existential dread in modern society",
    "Climate change policy",
    "Cyber security ethics",
    "Transcendental meditation",
    "The philosophy of mind",
    "Multiverse theory",
    "Cognitive biases in decision making",
    "Postcolonial theory",
    "Urban planning and architecture",
    "The future of education",
    "Virtual economies",
    "Consciousness and psychedelics",
    "Ethical implications of gene editing",
    "Technological singularity",
    "Spirituality and science",
    "Epigenetics and behavior",
    "Intersection of art and technology",
    "Feminist theory",
    "Minimalism in art and lifestyle",
    "AI and creativity",
    "History of philosophy",
    "Social media’s influence on society",
    "The evolution of language",
    "Environmental ethics",
    "The rise of cryptocurrency",
    "Digital surveillance",
    "The power of narrative",
    "Artificial life and robotics",
    "Existential psychotherapy",
    "Memory and identity",
    "Philosophy of literature",
    "The future of work",
    "Biotechnology advancements",
    "Space exploration and ethics",
    "Political philosophy in the digital age",
    "Emotional intelligence",
    "Globalization and cultural identity",
    "Post-truth politics",
    "Cognitive science and artificial intelligence",
    "Digital transformation in business",
    "The art of storytelling",
    "Historical narratives and myth-making",
    "Behavioral economics",
    "The impact of automation on society",
    "Virtual reality and human connection",
    "New media art",
    "The evolution of music in the digital era"
  ]

  def run do
    generate_question(Enum.random(@topics))
  end

  @doc """
  Generates a single question based on the provided topic.
  """
  def generate_question(topic) when is_binary(topic) do
    template = Enum.random(@templates)
    String.replace(template, "{topic}", topic)
  end

  @doc """
  Generates a list of questions based on the provided topic and count.
  """
  def generate_questions(topic, count)
      when is_binary(topic) and is_integer(count) and count > 0 do
    1..count
    |> Enum.map(fn _ -> generate_question(topic) end)
  end
end
