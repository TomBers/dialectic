defmodule DialecticWeb.ThinkingTools do
  use Phoenix.Component
  use DialecticWeb, :verified_routes

  @groups [
    %{
      id: "understand",
      title: "Understand more deeply",
      short: "Understand",
      icon: "hero-light-bulb",
      question: "What does this idea really mean?",
      description: "Make the explanation clearer and uncover what it takes for granted.",
      tools: [
        %{
          key: "explain",
          label: "Explain an idea",
          help: "Unpack the reasoning and context so you can put the idea into your own words.",
          example: "Explain why adding more roads might not solve traffic congestion.",
          insight:
            "Look for the steps in the explanation. Which step could you explain to someone else, and which still needs work?"
        },
        %{
          key: "clarify",
          label: "Clarify terms",
          help:
            "Separate different meanings of a word or claim before deciding whether you agree.",
          example:
            "What does ‘fair access’ mean in this proposal: equal places, equal cost, or equal opportunity?",
          insight:
            "A clearer definition helps you see whether people disagree about the same thing."
        },
        %{
          key: "assumptions",
          label: "Surface assumptions",
          help:
            "Find the unstated conditions an argument depends on, then ask whether they hold.",
          example: "What does this plan assume about who can travel to the new library?",
          insight:
            "Identify an assumption whose failure would change the conclusion. That gives you something specific to investigate."
        }
      ]
    },
    %{
      id: "challenge",
      title: "Test and challenge",
      short: "Challenge",
      icon: "hero-magnifying-glass",
      question: "How well does the claim hold up?",
      description:
        "Look for exceptions, missing information and evidence that deserves checking.",
      tools: [
        %{
          key: "counterexample",
          label: "Test a counterexample",
          help: "Try a case that does not fit a general claim, so you can recognise its limits.",
          example:
            "Is there a case where more choice makes a decision harder rather than better?",
          insight:
            "An exception may narrow a claim rather than overturn it. Ask what the revised claim should say."
        },
        %{
          key: "says_who",
          label: "Examine the evidence",
          help:
            "Ask which sources support a claim and whether those sources justify the conclusion.",
          example:
            "What evidence supports the claim that this policy improves learning, and how was improvement measured?",
          insight:
            "Follow the sources and inspect their methods and limits. An AI source-check response is a starting point, not independent verification."
        },
        %{
          key: "blind_spots",
          label: "Find blind spots",
          help:
            "Notice missing people, conditions or information that could change your judgement.",
          example: "Whose experience is missing from this account of working from home?",
          insight:
            "Turn an omission into a focused question. A missing perspective is worth investigating, but is not automatically correct."
        }
      ]
    },
    %{
      id: "expand",
      title: "Expand understanding",
      short: "Expand",
      icon: "hero-arrow-trending-up",
      question: "Where could this idea lead?",
      description: "Explore connections, consequences and changes of circumstance.",
      tools: [
        %{
          key: "related_ideas",
          label: "Find related ideas",
          help: "Connect the idea to other concepts so you can see it in a wider setting.",
          example:
            "How does the idea of a public library connect to shared resources and equal access?",
          insight:
            "Choose a connection that helps explain the original question. Similar-sounding ideas may still differ in important ways."
        },
        %{
          key: "implications",
          label: "Follow the consequences",
          help: "Work through what would follow if a claim were true or a proposal were adopted.",
          example:
            "If this service becomes digital-only, what follows for people without reliable internet?",
          insight:
            "Trace the steps from the proposal to a possible outcome. Check the assumptions needed at each step."
        },
        %{
          key: "what_if",
          label: "Try a what-if",
          help: "Change one condition to discover which parts of the reasoning depend on it.",
          example:
            "What if the same transport policy were used in a rural area rather than a city?",
          insight:
            "Compare the changed situation with the original. Keep a hypothetical scenario distinct from something that actually happened."
        }
      ]
    },
    %{
      id: "compare",
      title: "Compare perspectives",
      short: "Compare",
      icon: "hero-scale",
      question: "What can another reading show me?",
      description: "Build fair cases and identify the differences that matter.",
      tools: [
        %{
          key: "who_disagrees",
          label: "Consider other perspectives",
          help: "Explore a relevant disagreement to see what your current account may overlook.",
          example:
            "How might a teacher and a student read this argument about classroom rules differently?",
          insight:
            "Ask what each perspective explains and what evidence would help distinguish them. You do not need an opposing view for every claim."
        },
        %{
          key: "steel_man",
          label: "Strengthen an argument",
          help: "Build a fair, strong version of an argument before assessing it.",
          example:
            "What is the strongest reasonable case for keeping this rule, even if I dislike it?",
          insight:
            "Try answering the strongest case rather than an easy caricature. Understanding a case does not require agreeing with it."
        },
        %{
          key: "thesis",
          label: "Build a supporting case",
          help:
            "Make the reasons in favour of a claim explicit, so you can assess their strength.",
          example: "What are the strongest reasons for making public transport free?",
          insight:
            "Separate the main claim from the reasons offered for it. Which reason carries the most weight?"
        },
        %{
          key: "antithesis",
          label: "Build a challenging case",
          help:
            "Develop reasons against a claim to expose a consequential weakness or trade-off.",
          example: "What is the strongest objection to making public transport free?",
          insight:
            "Check whether an objection defeats the claim, limits it or calls for a better design."
        },
        %{
          key: "pros_cons",
          label: "Pro | Con",
          help:
            "Put supporting and challenging cases alongside one another to compare their reasons.",
          example: "Compare the strongest case for and against extending the school day.",
          insight:
            "The number of points on each side does not settle the question. Compare their relevance, evidence and importance.",
          availability:
            "In the app, Pro | Con creates both branches. An MCP assistant builds them with separate supporting-case and challenging-case requests."
        }
      ]
    },
    %{
      id: "connect",
      title: "Connect ideas and plan ahead",
      short: "Connect",
      icon: "hero-map",
      question: "What have I learned, and what comes next?",
      description: "Bring useful findings together or choose the next question to pursue.",
      tools: [
        %{
          key: "synthesis",
          label: "Connect chosen branches",
          help:
            "Bring existing ideas into a new explanation while keeping disagreements and open questions visible.",
          example:
            "Bring these branches together: where do they agree, and what difference remains unresolved?",
          insight:
            "Look for a connection that adds understanding. You can stop with useful findings without producing a synthesis.",
          availability:
            "Choose existing ideas from the same grid. The app connects two; MCP can connect two to five."
        },
        %{
          key: "learning_plan",
          label: "Plan useful next questions",
          help:
            "Suggest focused questions and thinking tools based on the idea you are actually exploring.",
          example: "What would be most useful to investigate next in this explanation, and why?",
          insight:
            "Read the suggestions and choose the one that addresses a real gap. A saved plan does not execute its own steps."
        }
      ]
    }
  ]
  @aliases %{
    "ideas" => "related_ideas",
    "related_idea" => "related_ideas",
    "pro" => "thesis",
    "con" => "antithesis",
    "pro_con" => "pros_cons"
  }

  def groups, do: @groups
  def tools, do: Enum.flat_map(@groups, & &1.tools)

  def key(value) do
    candidate = Map.get(@aliases, value, value)
    if Enum.any?(tools(), &(&1.key == candidate)), do: candidate
  end

  def href(nil), do: ~p"/features/thinking-tools"

  def href(value) do
    anchor = key(value) || if(Enum.any?(@groups, &(&1.id == value)), do: value)
    if anchor, do: ~p"/features/thinking-tools" <> "#" <> anchor, else: href(nil)
  end

  def action_sections do
    labels = %{
      "clarify" => "Clarify Terms",
      "assumptions" => "Assumptions",
      "says_who" => "Source Check",
      "steel_man" => "Steel Man",
      "counterexample" => "Test",
      "who_disagrees" => "Other Perspectives",
      "implications" => "Implications",
      "blind_spots" => "Blind Spots",
      "what_if" => "What If"
    }

    for group <- @groups,
        moves = Enum.filter(group.tools, &Map.has_key?(labels, &1.key)),
        moves != [] do
      %{
        title: group.short,
        tools:
          Enum.map(moves, fn tool ->
            %{
              key: tool.key,
              label: labels[tool.key],
              icon: DialecticWeb.ColUtils.advanced_tool_icon(tool.key),
              blurb: DialecticWeb.ColUtils.advanced_tool_description(tool.key)
            }
          end)
      }
    end
  end

  attr :tool, :string, default: nil
  attr :new_tab, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def tool_link(assigns) do
    ~H"""
    <.link
      href={href(@tool)}
      target={if(@new_tab, do: "_blank")}
      rel={if(@new_tab, do: "noopener noreferrer")}
      class={[
        "rounded-sm underline decoration-current underline-offset-4 hover:decoration-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}<span :if={@new_tab} class="sr-only"> (opens in a new tab)</span>
    </.link>
    """
  end

  attr :id, :string, required: true

  def group_links(assigns) do
    assigns = assign(assigns, :groups, groups())

    ~H"""
    <ul id={@id} role="list" class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <li :for={group <- @groups}>
        <.link
          id={"#{@id}-#{group.id}"}
          href={href(group.id)}
          class="flex h-full gap-3 border border-stone-300 bg-white p-4 text-slate-950 hover:border-teal-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-700"
        >
          <span><span class="block font-semibold">{group.title}</span><span class="mt-1 block text-sm leading-6 text-slate-600">{group.question}</span></span>
        </.link>
      </li>
    </ul>
    """
  end
end
