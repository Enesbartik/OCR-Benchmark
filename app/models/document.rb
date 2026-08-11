class Document < ApplicationRecord
  has_one_attached :file

  has_many :ocr_runs, dependent: :destroy

  validates :name, presence: true
  validate :file_must_be_attached

  private

  def file_must_be_attached
    errors.add(:file, "seçilmelidir") unless file.attached?
  end
end