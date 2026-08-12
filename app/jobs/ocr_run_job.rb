class OcrRunJob < ApplicationJob
  queue_as :ocr

  RETRYABLE_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Timeout::Error,
    SocketError
  ].freeze

  retry_on(
    *RETRYABLE_ERRORS,
    wait: :polynomially_longer,
    attempts: 3
  ) do |job, error|
    ocr_run = OcrRun.find_by(id: job.arguments.first)

    next unless ocr_run

    ocr_run.update!(
      status: "failed",
      finished_at: Time.current,
      duration_ms: duration_for(ocr_run),
      error_message: error.message
    )
  end

  def perform(ocr_run_id)
    ocr_run = OcrRun.find(ocr_run_id)

    return if ocr_run.completed?

    ocr_run.update!(
      status: "running",
      started_at: ocr_run.started_at || Time.current,
      error_message: nil
    )

    runner_class =
      Ocr::ProviderRegistry.runner_for(
        ocr_run.provider
      )

    result =
      runner_class
        .new(ocr_run.document)
        .call

    ocr_run.update!(
      status: "completed",

      raw_response:
        result[:raw_response],

      extracted_text:
        result[:extracted_text],

      normalized_output:
        result[:normalized_output],

      page_count:
        result[:page_count],

      input_tokens:
        result[:input_tokens],

      output_tokens:
        result[:output_tokens],

      provider_model:
        result[:provider_model],

      finished_at:
        Time.current,

      duration_ms:
        duration_for(ocr_run),

      error_message:
        nil
    )

  rescue StandardError => error
    if retryable_error?(error)
      ocr_run&.update!(
        status: "queued",
        error_message: "Geçici hata: #{error.message}"
      )

      raise
    end

    ocr_run&.update!(
      status: "failed",
      finished_at: Time.current,
      duration_ms: duration_for(ocr_run),
      error_message: error.message
    )

    Rails.logger.error(
      "[OCR] Run #{ocr_run&.id} failed: " \
      "#{error.class}: #{error.message}"
    )
  end

  private

  def retryable_error?(error)
    RETRYABLE_ERRORS.any? do |error_class|
      error.is_a?(error_class)
    end
  end

  def duration_for(ocr_run)
    return unless ocr_run&.started_at

    (
      (Time.current - ocr_run.started_at) * 1000
    ).round
  end
end