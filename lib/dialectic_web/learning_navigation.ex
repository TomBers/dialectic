defmodule DialecticWeb.LearningNavigation do
  alias Dialectic.Learning

  def assign_return(socket, params) do
    context =
      if Map.has_key?(params, "learning") do
        context(socket.assigns[:current_user], params["learning"])
      else
        socket.assigns[:learning_return]
      end

    Phoenix.Component.assign(socket, :learning_return, context)
  end

  def with_return(params, nil), do: Keyword.delete(params, :learning)
  def with_return(params, context), do: Keyword.put(params, :learning, context.path)

  def context(nil, _path), do: nil

  def context(user, path) when is_binary(path) and byte_size(path) <= 4096 do
    case URI.parse(path) do
      %URI{scheme: nil, host: nil, path: "/my/learning", fragment: nil, query: query} ->
        params =
          URI.decode_query(query || "") |> Map.take(~w(collection saved q include_subfolders add))

        collection = Learning.get_collection(user, params["collection"])

        if is_nil(params["collection"]) || collection do
          query = URI.encode_query(params)

          %{
            path: "/my/learning" <> if(query == "", do: "", else: "?" <> query),
            label: if(collection, do: collection.name, else: "My Learning")
          }
        end

      _ ->
        nil
    end
  rescue
    ArgumentError -> nil
  end

  def context(_user, _path), do: nil
end
