defmodule TaskBunny.WorkerSupervisorTest do
  use ExUnit.Case, async: false
  import TaskBunny.TestSupport.QueueHelper
  alias TaskBunny.{Config, Connection, Queue, WorkerSupervisor}
  alias TaskBunny.TestSupport.JobTestHelper
  alias TaskBunny.TestSupport.JobTestHelper.TestJob

  @queue "task_bunny.worker_supervisor_test"
  @worker_name :"TaskBunny.Worker.#{@queue}"

  defp all_queues do
    [@queue] ++ Queue.sub_queues(@queue)
  end

  defp workers do
    [
      [queue: @queue, concurrency: 1, host: :default]
    ]
  end

  defp start_worker_supervisor do
    {:ok, pid} = WorkerSupervisor.start_link(:worker_superrvisor_test)
    pid
  end

  defp wait_for_worker_up(name \\ @worker_name) do
    Enum.find_value 1..100, fn (_) ->
      if pid = Process.whereis(name) do
        %{consuming: consuming} = GenServer.call(pid, :status)
        !is_nil(consuming)
        :timer.sleep(10)
        true
      else
        :timer.sleep(10)
        false
      end
    end
  end

  setup do
    clean(all_queues())
    JobTestHelper.setup

    :meck.new Config, [:passthrough]
    :meck.expect Config, :workers, fn () -> workers() end

    on_exit fn ->
      JobTestHelper.teardown
    end

    :ok
  end

  test "starts job worker" do
    pid = start_worker_supervisor()
    %{active: active} = Supervisor.count_children(pid)
    assert active == 1

    payload = %{"hello" => "world"}
    TestJob.enqueue(payload, queue: @queue)

    JobTestHelper.wait_for_perform()
    assert List.first(JobTestHelper.performed_payloads) == payload

    Supervisor.stop(pid)
  end

  describe "graceful_halt" do
    test "stops workers to consuming the job" do
      pid = start_worker_supervisor()
      wait_for_worker_up()

      assert WorkerSupervisor.graceful_halt(pid, 1000) == :ok

      payload = %{"hello" => "world2"}
      TestJob.enqueue(payload, queue: @queue)
      :timer.sleep(50)

      assert JobTestHelper.performed_count() == 0

      %{message_count: count} = Queue.state(
        Connection.get_connection(), @queue
      )

      assert count == 1
    end

    test "doesn't stop workers if the current running job didn't finish before timeout" do
      pid = start_worker_supervisor()
      wait_for_worker_up()

      payload = %{"sleep" => 60_000}
      TestJob.enqueue(payload, queue: @queue)
      JobTestHelper.wait_for_perform()

      assert {:error, _} = WorkerSupervisor.graceful_halt(pid, 100)
    end

    test "waits for current runnning jobs to be finished" do
      pid = start_worker_supervisor()
      wait_for_worker_up()

      payload = %{"sleep" => 200}
      TestJob.enqueue(payload, queue: @queue)
      JobTestHelper.wait_for_perform()

      assert :ok = WorkerSupervisor.graceful_halt(pid, 1000)
    end
  end
end
