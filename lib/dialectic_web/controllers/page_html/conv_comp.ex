defmodule DialecticWeb.PageHtml.ConvComp do
  use DialecticWeb, :live_component

  def create(assigns) do
    ~H"""
    <div class="mb-8 bg-white border border-gray-200 shadow-md rounded-xl p-8">
      <h2 class="text-3xl font-bold text-gray-800 mb-6">What would you like to talk about?</h2>
      <.form :let={f} for={%{}} action={~p"/conversation"} class="">
        <div class="space-y-6">
          <.input
            field={f[:conversation]}
            type="text"
            label=""
            id="conversation-input"
            class="w-full text-xl font-medium rounded-lg border-indigo-200 focus:border-indigo-500 focus:ring-indigo-500"
            placeholder="Enter your topic or question..."
          />
          <.button
            type="submit"
            class="w-full bg-indigo-500 hover:bg-indigo-600 text-white font-medium py-2 px-6 rounded-lg transition duration-150 ease-in-out"
          >
            <span class="flex items-center justify-center whitespace-nowrap">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-2"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.293 5.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L12.586 11H5a1 1 0 110-2h7.586l-2.293-2.293a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                />
              </svg>
            </span>
            Start Conversation
          </.button>
        </div>
      </.form>
      <script>
        function updateQuestion() {
          const container = document.getElementById("conversation-input");
          const button = document.getElementById("inspire-button");

          button.disabled = true;
          button.innerHTML = '<svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>';

          fetch("/api/random_question")
            .then(response => response.json())
            .then(data => {
              container.value = data.question;
              container.focus();

              // Re-enable button and restore text after brief delay
              setTimeout(() => {
                button.disabled = false;
                button.innerHTML = '<span class="flex items-center whitespace-nowrap"><svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor"><path d="M11 3a1 1 0 10-2 0v1a1 1 0 102 0V3zM15.657 5.757a1 1 0 00-1.414-1.414l-.707.707a1 1 0 001.414 1.414l.707-.707zM18 10a1 1 0 01-1 1h-1a1 1 0 110-2h1a1 1 0 011 1zM5.05 6.464A1 1 0 106.464 5.05l-.707-.707a1 1 0 00-1.414 1.414l.707.707zM5 10a1 1 0 01-1 1H3a1 1 0 110-2h1a1 1 0 011 1zM8 16v-1h4v1a2 2 0 11-4 0zM12 14c.015-.34.208-.646.477-.859a4 4 0 10-4.954 0c.27.213.462.519.476.859h4.002z"></path></svg>Inspire Me</span>';
              }, 600);
            })
            .catch(error => {
              console.error('Error fetching new question:', error);
              button.disabled = false;
              button.innerHTML = 'Inspire Me';
            });
        }
      </script>
      <div class="flex justify-between items-center mt-8">
        <div class="text-sm text-gray-500 italic">Find your next great discussion</div>
        <div class="flex items-center">
          <button
            id="inspire-button"
            class="bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 text-white font-medium py-2.5 px-5 rounded-lg transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 shadow-md hover:shadow-lg transform hover:-translate-y-0.5"
            onclick="updateQuestion()"
          >
            <span class="flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-2"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M11 3a1 1 0 10-2 0v1a1 1 0 102 0V3zM15.657 5.757a1 1 0 00-1.414-1.414l-.707.707a1 1 0 001.414 1.414l.707-.707zM18 10a1 1 0 01-1 1h-1a1 1 0 110-2h1a1 1 0 011 1zM5.05 6.464A1 1 0 106.464 5.05l-.707-.707a1 1 0 00-1.414 1.414l.707.707zM5 10a1 1 0 01-1 1H3a1 1 0 110-2h1a1 1 0 011 1zM8 16v-1h4v1a2 2 0 11-4 0zM12 14c.015-.34.208-.646.477-.859a4 4 0 10-4.954 0c.27.213.462.519.476.859h4.002z">
                </path>
              </svg>
              Inspire Me
            </span>
          </button>
          <.link
            navigate={~p"/ideas/all"}
            class="ml-4 flex items-center text-indigo-600 font-semibold hover:text-indigo-800 transition-colors duration-200 group"
          >
            More ideas
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 ml-1 group-hover:translate-x-1 transition-transform duration-200"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M12.293 5.293a1 1 0 011.414 0l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-2.293-2.293a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            </svg>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
