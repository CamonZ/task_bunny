defmodule TaskBunny.WorkerSupervisor do
  @moduledoc """
  Worker supervisor for TaskBunny.

  It supervises all Workers with one_for_one strategy.

  It will receive all jobs that need workers when started and will start a worker for each job.
  """

  use Supervisor

  alias TaskBunny.Worker

  @type jobs :: list({host :: atom, job :: atom, concurrenct :: integer})

  @spec start_link(jobs) :: {:ok, pid} | {:error, term}
  def start_link(jobs) do
    Supervisor.start_link(__MODULE__, jobs)
  end

  @spec init(jobs) :: {:ok, {:supervisor.sup_flags, [Supervisor.Spec.spec]}} | :ignore
  def init(jobs) do
    jobs
    |> Enum.filter(fn ({_, job, _}) -> Code.ensure_loaded?(job) end)
    |> Enum.map(fn ({host, job, concurrency}) ->
         worker(
          Worker,
          [{host, job, concurrency}],
          id: "task_bunny.worker.#{job.queue_name}"
        )
       end)
    |> supervise(strategy: :one_for_one)
  end
end
