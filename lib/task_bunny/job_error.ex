defmodule TaskBunny.JobError do
  @moduledoc """
  A struct that holds an error information occured during the job processing.

  ## Attributes

  - job: the job module failed
  - payload: the payload(arguments) for the job execution
  - error_type: the type of the error. :exception, :return_value, :timeout or :exit
  - exception: the inner exception (option)
  - stacktrace: the stacktrace (only available for the exception)
  - return_value: the return value from the job (only available for the return value error)
  - reason: the reason information passed with EXIT signal (only available for exit error)
  - raw_body: the raw body for the message
  - meta: the meta data given by RabbitMQ
  - failed_count: the number of failures for the job processing request
  - queue: the name of the queue
  - concurrency: the number of concurrent job processing of the worker
  - pid: the process ID of the worker
  - reject: sets true if the job is rejected for the failure (means it won't be retried again)

  """

  @type t :: %__MODULE__{
    job: atom,
    payload: any,
    error_type: :exception | :return_value | :timeout | :exit | nil,
    exception: struct | nil,
    stacktrace: list(tuple) | nil,
    return_value: any,
    reason: any,
    raw_body: String.t,
    meta: map,
    failed_count: integer,
    queue: String.t,
    concurrency: integer,
    pid: pid,
    reject: boolean
  }

  defstruct [
    job: nil,
    payload: nil,
    error_type: nil,
    exception: nil,
    stacktrace: nil,
    return_value: nil,
    reason: nil,
    raw_body: "",
    meta: %{},
    failed_count: 0,
    queue: "",
    concurrency: 1,
    pid: nil,
    reject: false
  ]

  @doc false
  def handle_exception(job, payload, exception) do
    %__MODULE__{
      job: job,
      payload: payload,
      error_type: :exception,
      exception: exception,
      stacktrace: System.stacktrace()
    }
  end

  @doc false
  def handle_exit(job, payload, reason) do
    %__MODULE__{
      job: job,
      payload: payload,
      error_type: :exit,
      reason: reason
    }
  end

  @doc false
  def handle_return_value(job, payload, return_value) do
    %__MODULE__{
      job: job,
      payload: payload,
      error_type: :return_value,
      return_value: return_value
    }
  end

  @doc false
  def handle_timeout(job, payload) do
    %__MODULE__{
      job: job,
      payload: payload,
      error_type: :timeout
    }
  end
end
