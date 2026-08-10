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

  private

  def document_params
    params.require(:document).permit(:name, :notes, :file)
  end

end
