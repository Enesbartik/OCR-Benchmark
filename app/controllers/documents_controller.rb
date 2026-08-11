class DocumentsController < ApplicationController


    def index
    @documents = Document.order(created_at: :desc)
    end

    def new
    @document = Document.new
    end

    def create
    @document = Document.new(document_params)
    @document.document_type = "declaration"

      if @document.save
      redirect_to documents_path
      else
      render :new, status: :unprocessable_entity
      end
    end
    
    def run_azure_ocr
      document = Document.find(params[:id])

      Ocr::AzureRunner.new(document).call

      redirect_to documents_path,
                  notice: "Azure OCR tamamlandı."
    rescue => error
      redirect_to documents_path,
                  alert: "Azure OCR başarısız: #{error.message}"
    end
  private

  def document_params
    params.require(:document).permit(:name, :notes, :file)
  end

end
