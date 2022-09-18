defmodule Hyacinth.Warehouse do
  @moduledoc """
  The Warehouse context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Hyacinth.Repo
  alias Hyacinth.Warehouse.{Dataset, Object, DatasetObject}

  @type object_tuple :: {String.t, String.t}
  @type parent_tuple :: {String.t, String.t, [object_tuple]}

  @doc """
  Returns the list of datasets.

  ## Examples

      iex> list_datasets()
      [%Dataset{}, ...]

  """
  def list_datasets do
    Repo.all(Dataset)
  end

  @doc """
  Gets a single dataset.

  Raises `Ecto.NoResultsError` if the Dataset does not exist.

  ## Examples

      iex> get_dataset!(123)
      %Dataset{}

      iex> get_dataset!(456)
      ** (Ecto.NoResultsError)

  """
  def get_dataset!(id), do: Repo.get!(Dataset, id)

  @doc """
  Creates a root dataset (a dataset with no parent).
  """
  @spec create_dataset(params :: %{atom => term}, format :: atom, object_tuples :: [parent_tuple] | [object_tuple] | [%Object{}]) :: any
  def create_dataset(params, format, object_tuples) when is_map(params) and is_list(object_tuples) do
    Multi.new()
    |> Multi.insert(:dataset, Dataset.create_changeset(%Dataset{}, params))
    |> Multi.run(:objects, fn _repo, _values ->
      objects =
        case object_tuples do
          [{_hash, _name, _children} | _] ->
            Enum.map(object_tuples, fn {tree_hash, tree_name, child_tuples} ->
              tree_object = Repo.insert! %Object{hash: tree_hash, type: :tree, name: tree_name, file_type: format}

              Enum.map(child_tuples, fn {hash, name} ->
                Repo.insert! %Object{hash: hash, type: :blob, name: name, file_type: format, parent_tree_id: tree_object.id}
              end)

              tree_object
            end)

          [{_hash, _name} | _] ->
            Enum.map(object_tuples, fn {hash, name} ->
              Repo.insert! %Object{hash: hash, type: :blob, name: name, file_type: format}
            end)

          [%Object{} | _] ->
            object_tuples
        end

      {:ok, objects}
    end)
    |> Multi.run(:dataset_objects, fn _repo, %{dataset: %Dataset{} = dataset, objects: objects} ->
      dataset_objects =
        objects
        |> Enum.map(fn %Object{} = object -> %DatasetObject{dataset_id: dataset.id, object_id: object.id} end)
        |> Enum.map(&Repo.insert/1)

      {:ok, dataset_objects}
    end)
    |> Repo.transaction()
  end



  @doc """
  Lists all objects which belong to the given dataset.
  """
  def list_objects(%Dataset{} = dataset) do
    Repo.all(
      from o in Ecto.assoc(dataset, :objects),
      select: o,
      preload: :children
    )
  end

  @doc """
  Gets a single Object.

  Raises `Ecto.NoResultsError` if the Object does not exist.

  ## Examples

      iex> get_object!(123)
      %Object{}

      iex> get_object!(456)
      ** (Ecto.NoResultsError)

  """
  def get_object!(id), do: Repo.get!(Object, id)
end
