defmodule HyacinthWeb.LabelSessionLive.Label do
  use HyacinthWeb, :live_view

  alias Hyacinth.Labeling
  alias Hyacinth.Labeling.{LabelJob, Note, LabelJobType}

  defmodule ViewerSelectForm do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :viewer, Ecto.Enum, values: [:basic, :advanced], default: :advanced
      field :auto_next, :boolean, default: true
    end

    @doc false
    def changeset(viewer_select_form, attrs) do
      viewer_select_form
      |> cast(attrs, [:viewer, :auto_next])
      |> validate_required([:viewer, :auto_next])
    end
  end

  def mount(_params, _session, socket) do
    socket = assign(socket, %{
      viewer_select_changeset: ViewerSelectForm.changeset(%ViewerSelectForm{}, %{}),

      next_timer_nonce: 0,

      modal: nil,

      disable_primary_nav: true,
      use_wide_layout: true,
    })

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    label_session = Labeling.get_label_session_with_elements!(params["label_session_id"])
    element = Labeling.get_label_element!(label_session, params["element_index"])
    labels = Labeling.list_element_labels(element)

    object_label_options =
      case LabelJobType.list_object_label_options(label_session.job.type, label_session.job.options) do
        options when is_list(options) -> options
        nil -> Enum.map(1..(length(element.objects) - 1), fn _i -> nil end)
      end

    socket = assign(socket, %{
      label_session: label_session,
      element: element,
      labels: labels,

      object_label_options: object_label_options,
      current_value: if(length(labels) == 0, do: nil, else: hd(labels).value.option),
      started_at: DateTime.utc_now(),

      note_changeset: Note.changeset(element.note || %Note{}, %{}),
    })
    {:noreply, socket}
  end

  defp jump_element_relative(socket, amount) do
    new_index =
      socket.assigns.element.element_index + amount
      |> min(length(socket.assigns.label_session.elements) - 1)
      |> max(0)

    if new_index == socket.assigns.element.element_index do
      socket
    else
      path = Routes.live_path(socket, HyacinthWeb.LabelSessionLive.Label, socket.assigns.label_session, new_index)
      push_patch(socket, to: path)
    end
  end

  defp check_complete(socket) do
    elements = socket.assigns.label_session.elements
    
    on_last_element = socket.assigns.element.element_index == length(elements) - 1
    all_complete = Enum.all?(elements, fn element -> length(element.labels) > 0 end)

    if on_last_element and all_complete do
      assign(socket, :modal, :labeling_complete)
    else
      socket
    end
  end

  defp start_next_timer(socket) do
    nonce = socket.assigns.next_timer_nonce + 1
    :timer.send_after(300, {:next_timer_complete, nonce})
    assign(socket, :next_timer_nonce, nonce)
  end

  defp set_label(label_value, socket) do
    Labeling.create_label_entry!(socket.assigns.element, socket.assigns.current_user, label_value, socket.assigns.started_at)

    labels = Labeling.list_element_labels(socket.assigns.element)

    socket
    |> assign(%{
      label_session: Labeling.get_label_session_with_elements!(socket.assigns.label_session.id),
      labels: labels,
      started_at: DateTime.utc_now(),
      current_value: hd(labels).value.option,
    })
    |> check_complete()
    |> start_next_timer()
  end

  def handle_event("set_label", %{"label" => label_value}, socket) do
    socket = set_label(label_value, socket)
    {:noreply, socket}
  end

  def handle_event("set_label_key", %{"key" => key}, socket) when key in ["1", "2", "3", "4", "5", "6", "7", "8", "9"] do
    label_i = String.to_integer(key) - 1

    %LabelJob{} = job = socket.assigns.label_session.job
    job_type_options = LabelJobType.list_object_label_options(job.type, job.options)
    all_label_options = (job_type_options || []) ++ job.label_options

    label_value = Enum.at(all_label_options, label_i)
    case label_value do
      label_value when is_binary(label_value) ->
        socket = set_label(label_value, socket)
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("set_label_key", _value, socket), do: {:noreply, socket}

  def handle_event("note_change", %{"note" => params}, socket) do
    changeset =
      (socket.assigns.element.note || %Note{})
      |> Note.changeset(params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, :note_changeset, changeset)}
  end

  def handle_event("note_submit", %{"note" => params}, socket) do
    case socket.assigns.element.note do
      nil ->
        case Labeling.create_note(socket.assigns.current_user, socket.assigns.element, params) do
          {:ok, _values} ->
            element = Labeling.get_label_element!(socket.assigns.label_session, socket.assigns.element.element_index)
            socket = assign(socket, %{
              element: element,
              note_changeset: Note.changeset(element.note, %{}),
            })
            {:noreply, socket}

          {:error, :note, %Ecto.Changeset{} = changeset, _changes} ->
            {:noreply, assign(socket, :note_changeset, changeset)}
        end

      %Note{} = existing_note ->
        case Labeling.update_note(socket.assigns.current_user, existing_note, params) do
          {:ok, _values} ->
            element = Labeling.get_label_element!(socket.assigns.label_session, socket.assigns.element.element_index)
            socket = assign(socket, %{
              element: element,
              note_changeset: Note.changeset(element.note, %{}),
            })
            {:noreply, socket}

          {:error, :note, %Ecto.Changeset{} = changeset, _changes} ->
            {:noreply, assign(socket, :note_changeset, changeset)}
        end
    end
  end

  def handle_event("reset_timer", _params, socket) do
    {:noreply, assign(socket, :started_at, DateTime.utc_now())}
  end

  def handle_event("viewer_change", %{"viewer_select_form" => params}, socket) do
    changeset = ViewerSelectForm.changeset(%ViewerSelectForm{}, params)
    {:noreply, assign(socket, :viewer_select_changeset, changeset)}
  end

  def handle_event("prev_element", _value, socket) do
    socket = jump_element_relative(socket, -1)
    {:noreply, socket}
  end

  def handle_event("next_element", _value, socket) do
    socket = jump_element_relative(socket, 1)
    {:noreply, socket}
  end

  def handle_event("open_modal_label_history", _value, socket) do
    {:noreply, assign(socket, :modal, :label_history)}
  end

  def handle_event("open_modal_keymap", _value, socket) do
    {:noreply, assign(socket, :modal, :keymap)}
  end

  def handle_event("close_modal", _value, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  def handle_info({:next_timer_complete, nonce}, socket) do
    next_enabled = Ecto.Changeset.apply_changes(socket.assigns.viewer_select_changeset).auto_next
    if next_enabled and nonce == socket.assigns.next_timer_nonce do
      socket = jump_element_relative(socket, 1)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
