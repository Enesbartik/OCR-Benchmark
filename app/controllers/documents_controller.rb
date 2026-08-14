class DocumentsController < ApplicationController


    def index
      @documents = Document.with_attached_file.order(created_at: :desc)
    
      @ocr_runs = OcrRun
        .includes(document: { file_attachment: :blob })
        .order(created_at: :desc)
    end   

    def destroy
      @document = Document.find(params[:id])
      @document.destroy!

      redirect_to documents_path,
                  notice: "Dosya başarıyla silindi."
    end

    def new
      @selected_document = Document.find_by(id: params[:document_id])
    
      @document = Document.new
    
      if @selected_document
        @document.name = @selected_document.name
        @document.notes = @selected_document.notes
      end
    end   

def create
  @selected_document = Document.find_by(id: params[:document_id])

  if @selected_document
    # Var olan dosyayı tekrar kullanıyoruz.
    target_document = @selected_document

    # Form hata verirse new sayfasını tekrar düzgün gösterebilmek için.
    @document = Document.new(
      name: @selected_document.name,
      notes: params.dig(:document, :notes).presence || @selected_document.notes
    )
  else
    # Normal yeni dosya yükleme.
    @document = Document.new(document_params)
    @document.document_type = "declaration"

    target_document = @document
  end


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


  run_note =
    params.dig(:document, :notes).presence ||
    target_document.notes


  ocr_runs = []

  ActiveRecord::Base.transaction do

    # Eğer yeni dosyaysa kaydet.
    # Mevcut dosyaysa tekrar Document oluşturma.
    target_document.save! unless target_document.persisted?

    providers.each do |provider|
      ocr_runs << target_document.ocr_runs.create!(
        provider: provider,
        status: "queued",
        note: run_note
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
