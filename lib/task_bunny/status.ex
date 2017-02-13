defmodule TaskBunny.Status do
  @moduledoc ~S"""
  Modules that handles TaskBunny status.
  """

  alias TaskBunny.Status
  alias TaskBunny.Status.Worker

  @typedoc ~S"""
  The Worker status contains the follow fields:
    - `version`, the current status version.
    - `up`, whether the `TaskBunny.Supervisor` is running.
    - `connected`, whether a connection to RabbitMQ has been made.
    - `workers`, list of worker statusses.
  """
  @type t :: %__MODULE__{version: String.t, up: boolean, connected: boolean, workers: list(Worker.t)}

  defstruct version: "1", up: true, connected: false, workers: []

  @doc ~S"""
  Returns TaskBunny status.
  """
  @spec overview(supervisor :: atom) :: Status.t
  def overview(supervisor \\ TaskBunny.Supervisor) do
    case supervisor_alive?(supervisor) do
      true ->
        %Status{
          up: true,
          connected: get_connection_status(),
          workers: get_workers_status(supervisor),
        }
      _ ->
        %Status{
          up: false,
          connected: get_connection_status(),
        }
    end
  end

  @doc ~S"""
  Returns TaskBunny metrics.
  """
  @spec metrics(supervisor :: atom) :: keyword
  def metrics(supervisor \\ TaskBunny.Supervisor) do
    case supervisor_alive?(supervisor) do
      true ->
        {runners, succeeded, failed, rejected} =
          supervisor
          |> get_workers_status()
          |> Enum.reduce({[], [], [], []}, &get_worker_metrics/2)

        [
          task_bunny_job_runners_now: {runners, :gauge, "Current amount of TaskBunny runners."},
          task_bunny_jobs_succeeded_total: {succeeded, :counter, "The amount of succeeded TaskBunny jobs."},
          task_bunny_jobs_failed_total: {failed, :counter, "The amount of failed TaskBunny jobs."},
          task_bunny_jobs_rejected_total: {rejected, :counter, "The amount of rejected TaskBunny jobs."},
        ]
      false ->
        []
    end
  end

  @doc ~S"""
  Returns TaskBunny `:wobserver` page.
  """
  @spec page(supervisor :: atom) :: map
  def page(supervisor \\ TaskBunny.Supervisor) do
    page =
      %{
        status: %{
          running: supervisor_alive?(supervisor),
          connected: get_connection_status(),
        }
      }

    case page.status.running do
      true ->
        page
        |> Map.put_new(:workers, get_workers_page(supervisor))
      false ->
        page
    end
  end

  @spec get_connection_status() :: boolean
  defp get_connection_status do
    case TaskBunny.Connection.get_connection do
      nil -> false
      _ -> true
    end
  end

  @spec supervisor_alive?(supervisor :: atom) :: boolean
  defp supervisor_alive?(supervisor) do
    case Process.whereis(supervisor) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @spec get_workers_status(supervisor :: atom) :: list(Worker.t)
  defp get_workers_status(supervisor) do
    supervisor
    |> Supervisor.which_children
    |> Enum.map(&get_worker_supervisor_status/1)
    |> List.flatten
  end

  @spec get_workers_status({TaskBunny.WorkerSupervisor, pid :: pid, atom, list()}) :: list(Worker.t)
  defp get_worker_supervisor_status({TaskBunny.WorkerSupervisor, pid, _atom, _list}) do
    pid
    |> Supervisor.which_children
    |> Enum.map(&Status.Worker.get/1)
  end

  @spec get_workers_status(any) :: []
  defp get_worker_supervisor_status(_) do
    []
  end

  @spec get_workers_page(supervisor :: atom) :: list(map)
  defp get_workers_page(supervisor) do
    supervisor
    |> get_workers_status()
    |> Enum.map(fn worker -> %{
          job: worker.job,
          runners: worker.runners,
          channel: worker.channel,
          succeeded: worker.stats.succeeded,
          failed: worker.stats.failed,
          rejected: worker.stats.rejected,
        }
      end)
  end

  @spec get_worker_metrics(workers :: Worker.t, {list, list, list, list}) :: {list, list, list, list}
  defp get_worker_metrics(worker, {runners, succeeded, failed, rejected}) do
    {
      [{worker.runners, [job: worker.job]} | runners],
      [{worker.stats.succeeded, [job: worker.job]} | succeeded],
      [{worker.stats.failed, [job: worker.job]} | failed],
      [{worker.stats.rejected, [job: worker.job]} | rejected]
    }
  end
end