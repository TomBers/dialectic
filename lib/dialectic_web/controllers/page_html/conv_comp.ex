defmodule DialecticWeb.PageHtml.ConvComp do
  use DialecticWeb, :live_component

  def create(assigns) do
    ~H"""
    <div class="mb-8 bg-white shadow-md rounded-lg p-6">
      <.form :let={f} for={%{}} action={~p"/conversation"} class="">
        <div class="space-y-4">
          <.input
            field={f[:conversation]}
            type="text"
            label="Start a conversation"
            id="conversation-input"
          />
          <.button
            type="submit"
            class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-4 rounded-md transition duration-150 ease-in-out"
          >
            Submit
          </.button>
        </div>
      </.form>
      <script>
        function updateQuestion() {
          const container = document.getElementById("conversation-input");

          fetch("/api/random_question")
            .then(response => response.json())
            .then(data => {
              container.value = data.question;
            })
            .catch(error => console.error('Error fetching new question:', error));
        }
      </script>
      <div class="flex justify-end items-center mt-4">
        <button
          id="inspire-button"
          class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50"
          onclick="updateQuestion()"
        >
          Inspire Me
        </button>
        <.link navigate={~p"/ideas/all"} class="text-xl text-blue-600 ml-4 hover:text-blue-400">
          More ideas &rarr;
        </.link>
      </div>
    </div>
    """
  end
end
