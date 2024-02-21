defmodule Hyacinth.WarehouseTest do
  use Hyacinth.DataCase

  import Hyacinth.WarehouseFixtures
  import Hyacinth.LabelingFixtures

  alias Hyacinth.Warehouse
  alias Hyacinth.Warehouse.{Dataset, Object}

  describe "list_datasets/0" do
    test "returns all datasets" do
      dataset = root_dataset_fixture()
      assert Warehouse.list_datasets() == [dataset]
    end

    test "returns empty list if there are no datasets" do
      assert Warehouse.list_datasets() == []
    end
  end

  describe "list_datasets_with_format/1" do
    test "returns all matching datasets" do
      dataset_fixture(%{}, many_object_params_fixtures(nil, nil, :png))
      dataset_fixture(%{}, many_object_params_fixtures(nil, nil, :png))
      dataset_fixture(%{}, many_object_params_fixtures(nil, nil, :dicom))

      assert length(Warehouse.list_datasets_with_format(:png)) == 2
      assert length(Warehouse.list_datasets_with_format(:dicom)) == 1
    end

    test "returns empty list if there are no matching datasets" do
      dataset_fixture(%{}, many_object_params_fixtures(nil, nil, :dicom))

      assert length(Warehouse.list_datasets_with_format(:png)) == 0
    end
  end

  describe "list_datasets_with_stats/0" do
    test "returns all datasets with counts" do
      dataset1 = root_dataset_fixture()
      dataset2 = root_dataset_fixture(nil, 10)
      dataset3 = root_dataset_fixture()
      label_job_fixture(%{}, dataset3)
      label_job_fixture(%{}, dataset3)

      assert Warehouse.list_datasets_with_stats == [
        %Warehouse.DatasetStats{dataset: dataset1, num_objects: 3, num_jobs: 0},
        %Warehouse.DatasetStats{dataset: dataset2, num_objects: 10, num_jobs: 0},
        %Warehouse.DatasetStats{dataset: dataset3, num_objects: 3, num_jobs: 2},
      ]
    end

    test "returns empty list if there are no datasets" do
      assert Warehouse.list_datasets_with_stats() == []
    end
  end

  describe "get_dataset!/1" do
    test "returns the dataset with given id" do
      dataset = root_dataset_fixture()
      assert Warehouse.get_dataset!(dataset.id) == dataset
    end
  end

  describe "get_dataset_stats!/1" do
    test "returns the dataset stats for the dataset with the given id" do
      dataset = root_dataset_fixture()
      label_job_fixture(%{}, dataset)
      label_job_fixture(%{}, dataset)

      assert Warehouse.get_dataset_stats!(dataset.id) == %Warehouse.DatasetStats{dataset: dataset, num_objects: 3, num_jobs: 2}
    end
  end

  describe "create_dataset/2" do
    test "creates a flat (png) root dataset" do
      object_params = many_object_params_fixtures()

      {:ok, %{dataset: %Dataset{} = dataset}} = Warehouse.create_dataset(%{name: "Some Dataset", type: :root}, object_params)

      assert dataset.name == "Some Dataset"
      assert dataset.type == :root

      objects = Warehouse.list_objects(dataset)
      assert length(objects) == 3
      assert Enum.map(objects, fn %Object{} = o -> o.name end) == ["object1.png", "object2.png", "object3.png"]
      assert Enum.map(objects, fn %Object{} = o -> o.hash end) == Enum.map(object_params, &(&1.hash))
    end

    test "creates a container (dicom) root dataset" do
      children1 = many_object_params_fixtures(3, "o1s", :dicom)
      children2 = many_object_params_fixtures(2, "o2s", :dicom)
      children3 = many_object_params_fixtures(4, "o3s", :dicom)

      object_params = [
        %{
          hash: Warehouse.Store.hash_hashes(Enum.map(children1, &(&1.hash))),
          type: :tree,
          name: "object1",
          format: :dicom,
          children: children1,
        },
        %{
          hash: Warehouse.Store.hash_hashes(Enum.map(children2, &(&1.hash))),
          type: :tree,
          name: "object2",
          format: :dicom,
          children: children2,
        },
        %{
          hash: Warehouse.Store.hash_hashes(Enum.map(children3, &(&1.hash))),
          type: :tree,
          name: "object3",
          format: :dicom,
          children: children3,
        },
      ]

      {:ok, %{dataset: dataset}} = Warehouse.create_dataset(%{name: "Some Dataset", type: :root}, object_params)

      assert dataset.name == "Some Dataset"
      assert dataset.type == :root

      objects = Warehouse.list_objects(dataset)
      assert length(objects) == 3
      assert Enum.map(objects, fn %Object{} = o -> o.hash end) == Enum.map(object_params, &(&1.hash))
      assert Enum.map(objects, fn %Object{} = o -> o.type end) == [:tree, :tree, :tree]
      assert Enum.map(objects, fn %Object{} = o -> o.name end) == ["object1", "object2", "object3"]
      assert Enum.map(objects, fn %Object{} = o -> o.format end) == [:dicom, :dicom, :dicom]

      assert length(Enum.at(objects, 0).children) == 3
      assert length(Enum.at(objects, 1).children) == 2
      assert length(Enum.at(objects, 2).children) == 4

      object3slice2 = Enum.at(Enum.at(objects, 2).children, 1)
      assert object3slice2.hash == hash_fixture("o3s2")
      assert object3slice2.type == :blob
      assert object3slice2.name == "o3s2.dcm"
      assert object3slice2.format == :dicom
    end

    test "creates a derived dataset" do
      object_params = many_object_params_fixtures()

      {:ok, %{dataset: %Dataset{} = dataset}} = Warehouse.create_dataset(%{name: "Some Dataset", type: :derived}, object_params)

      assert dataset.name == "Some Dataset"
      assert dataset.type == :derived

      objects = Warehouse.list_objects(dataset)
      assert length(objects) == 3
      assert Enum.map(objects, fn %Object{} = o -> o.name end) == ["object1.png", "object2.png", "object3.png"]
      assert Enum.map(objects, fn %Object{} = o -> o.hash end) == Enum.map(object_params, &(&1.hash))
    end

    test "creates a derived dataset from existing objects" do
      existing_dataset = root_dataset_fixture()
      existing_objects = Warehouse.list_objects(existing_dataset)

      {:ok, %{dataset: %Dataset{} = dataset}} = Warehouse.create_dataset(%{name: "Some Dataset", type: :derived}, existing_objects)

      assert dataset.name == "Some Dataset"
      assert dataset.type == :derived

      objects = Warehouse.list_objects(dataset)
      assert objects == existing_objects
    end
  end

  describe "list_objects/1" do
    test "returns objects for dataset" do
      dataset = root_dataset_fixture(nil, 10)
      _other_dataset = root_dataset_fixture()

      objects = Warehouse.list_objects(dataset)
      assert length(objects) == 10
    end
  end

  describe "get_object/1" do
    test "returns the object with the given id" do
      _dataset = root_dataset_fixture()

      object = Warehouse.get_object!(1)
      assert %Object{} = object
      assert object.id == 1
    end

    test "raises if object does not exist" do
      _dataset = root_dataset_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Warehouse.get_object!(1000)
      end
    end
  end

  describe "Object.create_changeset/2" do
    test "valid for blob object" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :blob,
          name: "path/to/image1.png",
          format: :png,
        })

      assert changeset.valid? == true
    end

    test "valid for nested tree object" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :tree,
          name: "path/to/image1",
          format: :png,
          children: [
            %{hash: hash_fixture("c1"), type: :blob, name: "c1.png", format: :png},
            %{hash: hash_fixture("c2"), type: :blob, name: "c2.png", format: :png},
            %{hash: hash_fixture("c3"), type: :blob, name: "c3.png", format: :png},
          ],
        })

      assert changeset.valid? == true
    end

    test "invalid for tree object with nil children" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :tree,
          name: "path/to/image1",
          format: :png,
        })

      assert changeset.valid? == false
      assert changeset.errors == [{:type, {"must be blob if object has no children", []}}]
    end

    test "invalid for tree object with empty children" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :tree,
          name: "path/to/image1",
          format: :png,
          children: [],
        })

      assert changeset.valid? == false
      assert changeset.errors == [{:type, {"must be blob if object has no children", []}}]
    end

    test "invalid for blob object with nested children" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :blob,
          name: "path/to/image1",
          format: :png,
          children: [
            %{hash: hash_fixture("c1"), type: :blob, name: "c1.png", format: :png},
            %{hash: hash_fixture("c2"), type: :blob, name: "c2.png", format: :png},
            %{hash: hash_fixture("c3"), type: :blob, name: "c3.png", format: :png},
          ],
        })

      assert changeset.valid? == false
      assert changeset.errors == [{:type, {"must be tree if object has children", []}}]
    end

    test "invalid for nested tree object with nil children" do
      %Ecto.Changeset{} = changeset =
        Object.create_changeset(%Object{}, %{
          hash: hash_fixture("image1"),
          type: :tree,
          name: "path/to/image1",
          format: :png,
          children: [
            %{hash: hash_fixture("c1"), type: :blob, name: "c1.png", format: :png},
            %{hash: hash_fixture("c2"), type: :tree, name: "c2.png", format: :png},
            %{hash: hash_fixture("c3"), type: :blob, name: "c3.png", format: :png},
          ],
        })

      assert changeset.valid? == false
      assert Enum.at(changeset.changes.children, 0).valid? == true
      assert Enum.at(changeset.changes.children, 1).valid? == false
      assert Enum.at(changeset.changes.children, 2).valid? == true
      assert Enum.at(changeset.changes.children, 1).errors == [{:type, {"must be blob if object has no children", []}}]
    end
  end
end
