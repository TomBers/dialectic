defmodule Dialectic.Responses.GuidedLearningPlanTest do
  use ExUnit.Case, async: true

  alias Dialectic.Responses.{GuidedLearningPlan, RequestQueue}
  alias Dialectic.Workers.LLMWorker

  @valid_plan """
  ## Learning plan: Urban heat
  ### Best next actions
  - **Clarify terms** — Define successful adaptation before comparing policies.
  - **Test with a counterexample** — Examine where a common intervention failed.
  - **Find related ideas** — Connect heat policy to housing and public health.
  ### Paths to explore
  - **Cooling homes** — How can homes stay safe during heat waves? — Compares practical building interventions.
  - **Public space** — Which street designs reduce dangerous heat? — Connects planning choices to exposure.
  - **Health systems** — How should clinics prepare for extreme heat? — Tests readiness for vulnerable residents.
  - **Energy demand** — Can cooling expand without overloading the grid? — Links adaptation to infrastructure.
  - **Unequal exposure** — Who faces the greatest heat risk and why? — Surfaces distributional consequences.
  """

  test "registry provides unique executable tools" do
    tools = GuidedLearningPlan.tools()

    assert length(tools) == 11
    assert Enum.uniq_by(tools, & &1.key) == tools
    assert Enum.uniq_by(tools, & &1.label) == tools

    assert Enum.all?(tools, fn tool ->
             match?({:thinking_tool, tool} when is_atom(tool), tool.executor) or
               tool.executor in [:branch, :related_ideas]
           end)
  end

  test "validates and parses a complete plan" do
    assert {:ok, %{actions: actions, paths: paths}} =
             GuidedLearningPlan.validate(@valid_plan)

    assert Enum.map(actions, & &1.key) == ["clarify", "counterexample", "related_ideas"]
    assert length(paths) == 5
    assert Enum.at(paths, 0).question == "How can homes stay safe during heat waves?"
  end

  test "accepts one-character learning-plan titles" do
    content = String.replace(@valid_plan, "Urban heat", "R")

    assert {:ok, %{title: "R"} = plan} = GuidedLearningPlan.validate(content)
    assert {:ok, markdown} = GuidedLearningPlan.render(plan)
    assert markdown =~ "## Learning plan: R"
  end

  test "rejects values that become empty during normalization" do
    invalid_plans = [
      String.replace(@valid_plan, "Urban heat", "__"),
      String.replace(
        @valid_plan,
        "Define successful adaptation before comparing policies.",
        "`"
      ),
      String.replace(@valid_plan, "Cooling homes", "__")
    ]

    for invalid_plan <- invalid_plans do
      assert {:error, ["invalid structured learning plan"]} =
               GuidedLearningPlan.validate(invalid_plan)
    end
  end

  test "resolves legacy content-only learning plans" do
    assert {:ok, %{title: "Urban heat"}} =
             GuidedLearningPlan.resolve(%{guided_plan: nil, content: @valid_plan})

    assert {:error, _errors} =
             GuidedLearningPlan.resolve(%{guided_plan: nil, content: "generation failed"})
  end

  test "recognizes atom- and string-keyed submission reservations" do
    assert GuidedLearningPlan.submission_reserved?(
             %{reservations: ["action:clarify"]},
             "action:clarify"
           )

    assert GuidedLearningPlan.submission_reserved?(
             %{"reservations" => ["path:path-1"]},
             "path:path-1"
           )

    refute GuidedLearningPlan.submission_reserved?(%{}, "action:clarify")
  end

  test "normalizes serialized plans and renders canonical markdown" do
    {:ok, plan} = GuidedLearningPlan.validate(@valid_plan)
    serialized_plan = plan |> Jason.encode!() |> Jason.decode!()

    assert {:ok, normalized_plan} = GuidedLearningPlan.normalize(serialized_plan)
    assert normalized_plan == plan
    assert Enum.map(normalized_plan.paths, & &1.id) == Enum.map(1..5, &"path-#{&1}")

    assert {:ok, markdown} = GuidedLearningPlan.render(serialized_plan)
    assert markdown =~ "## Learning plan: Urban heat"
    assert markdown =~ "**Clarify terms**"
  end

  test "rejects tampered structured path identifiers" do
    {:ok, plan} = GuidedLearningPlan.validate(@valid_plan)
    tampered_plan = put_in(plan, [:paths, Access.at(0), :id], "another-path")

    assert {:error, ["invalid structured learning plan"]} =
             GuidedLearningPlan.normalize(tampered_plan)
  end

  test "rejects invented tools instead of exposing them as actions" do
    invalid_plan = String.replace(@valid_plan, "Clarify terms", "Search private databases")

    assert {:error, errors} = GuidedLearningPlan.validate(invalid_plan)
    assert "expected exactly three recognised actions" in errors

    refute Enum.any?(
             GuidedLearningPlan.actions(invalid_plan),
             &(&1.label == "Search private databases")
           )
  end

  test "rejects incomplete and malformed path sections" do
    invalid_plan =
      @valid_plan
      |> String.replace(
        "? — Compares practical building interventions.",
        ". — Compares practical building interventions."
      )
      |> String.replace(
        "- **Unequal exposure** — Who faces the greatest heat risk and why? — Surfaces distributional consequences.\n",
        ""
      )

    assert {:error, errors} = GuidedLearningPlan.validate(invalid_plan)
    assert "expected exactly five valid paths" in errors
  end

  test "builds a bounded repair instruction with validation feedback" do
    prompt =
      GuidedLearningPlan.repair_prompt(
        "Create a plan",
        String.duplicate("x", 9_000),
        ["expected exactly three recognised actions"]
      )

    assert prompt =~ "Rewrite it completely"
    assert prompt =~ "expected exactly three recognised actions"
    assert prompt =~ "Create a plan"
    assert String.length(prompt) < 9_000
  end

  test "worker accepts valid plans and allows only one repair attempt" do
    args = %{"instruction" => "Create a learning plan"}

    assert {:accept, %{actions: actions}} =
             LLMWorker.guided_learning_plan_response_action(args, @valid_plan)

    assert length(actions) == 3

    assert {:repair, repair_instruction, errors} =
             LLMWorker.guided_learning_plan_response_action(args, "not a plan")

    assert repair_instruction =~ "Rewrite it completely"
    assert errors != []

    assert {:reject, ^errors} =
             LLMWorker.guided_learning_plan_response_action(
               Map.put(args, "guided_plan_repair_attempt", true),
               "still not a plan"
             )
  end

  test "request jobs retain the guided-plan response contract" do
    params =
      RequestQueue.build_params(
        "Create a plan",
        "System prompt",
        %{id: "plan-1", user: "learner@example.com"},
        "graph-1",
        "topic-1",
        mode: :university,
        response_contract: "guided_learning_plan"
      )

    assert params.response_contract == "guided_learning_plan"
  end
end
