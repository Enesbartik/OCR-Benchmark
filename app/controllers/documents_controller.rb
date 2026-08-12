class DocumentsController < ApplicationController


    def index
      @ocr_runs = OcrRun
        .includes(document: { file_attachment: :blob })
        .order(created_at: :desc)
    end 

    def new
    @document = Document.new
    end

    def create
        @document = Document.new(document_params)
        @document.document_type = "declaration"

        providers =
        Array(params[:providers])
            .uniq
            .select { |provider| Ocr::ProviderRegistry.exists?(provider) }

        if providers.empty?
        @document.errors.add(
            :base,
            "En az bir OCR aracı seçmelisiniz."
        )

        render :new,
                status: :unprocessable_entity

        return
        end

        ocr_runs = []

        ActiveRecord::Base.transaction do
        @document.save!

        providers.each do |provider|
            ocr_runs << @document.ocr_runs.create!(
            provider: provider,
            status: "queued",
            note: @document.notes
            )
        end
        end

        ocr_runs.each do |ocr_run|
        OcrRunJob.perform_later(ocr_run.id)
        end

        redirect_to documents_path,
                    notice: "OCR çalıştırması kuyruğa eklendi."

        rescue ActiveRecord::RecordInvalid
          render :new,
             status: :unprocessable_entity
    end

    
  private

  def document_params
    params.require(:document).permit(:name, :notes, :file)
  end

end
