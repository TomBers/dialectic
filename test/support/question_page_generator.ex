defmodule Dialectic.Test.QuestionPageGenerator do
  def generate(source) do
    case Application.get_env(:dialectic, :question_page_test_mode) do
      :fail ->
        {:error, :test_failure}

      {:pause, pid} ->
        send(pid, {:question_generation_started, self()})

        receive do
          :continue -> {:ok, Dialectic.QuestionPageFixtures.content_attrs(source)}
        end

      _ ->
        {:ok, Dialectic.QuestionPageFixtures.content_attrs(source)}
    end
  end
end
