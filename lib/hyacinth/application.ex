defmodule Hyacinth.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Hyacinth.Repo,
      # Start the Telemetry supervisor
      HyacinthWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Hyacinth.PubSub},
      # Start the Endpoint (http/https)
      HyacinthWeb.Endpoint,
      # Start the Presence system
      HyacinthWeb.Presence,
      # Start the Pipeline Run TaskSupervisor
      {Task.Supervisor, name: Hyacinth.PipelineRunSupervisor},

      # Start a worker by calling: Hyacinth.Worker.start_link(arg)
      # {Hyacinth.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hyacinth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HyacinthWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
