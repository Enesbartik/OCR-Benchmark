class OcrRun < ApplicationRecord
  belongs_to :document

  enum :status, {
    queued: "queued",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, validate: true

  validates :provider, presence: true
end