import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input",
    "filename",
    "dropzone",
    "message",
    "icon",
    "selectedFile",
    "emptyState"
  ]

  connect() {
    this.dragCounter = 0
  }

  chooseFile() {
    this.inputTarget.click()
  }

  fileSelected() {
    const file = this.inputTarget.files[0]

    if (file) {
      this.showSelectedFile(file)
    } else {
      this.hideSelectedFile()
    }
  }

  dragEnter(event) {
    event.preventDefault()

    this.dragCounter += 1
    this.showDragState()
  }

  dragOver(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    event.preventDefault()

    this.dragCounter -= 1

    if (this.dragCounter <= 0) {
      this.dragCounter = 0
      this.resetDropzone()
    }
  }

  drop(event) {
    event.preventDefault()

    this.dragCounter = 0
    this.resetDropzone()

    const files = event.dataTransfer.files

    if (files.length === 0) return

    const file = files[0]

    if (!this.validFile(file)) {
      this.inputTarget.value = ""

      this.hideSelectedFile()

      this.emptyStateTarget.textContent =
        "Desteklenmeyen dosya türü. PDF, JPG, JPEG veya PNG yükleyin."

      this.emptyStateTarget.classList.remove("text-gray-500")
      this.emptyStateTarget.classList.add("text-red-600")

      return
    }

    const dataTransfer = new DataTransfer()

    dataTransfer.items.add(file)

    this.inputTarget.files = dataTransfer.files

    this.showSelectedFile(file)
  }

  removeFile() {
    this.inputTarget.value = ""

    this.hideSelectedFile()
    this.resetDropzone()
  }

  showSelectedFile(file) {
    this.filenameTarget.textContent = file.name

    this.selectedFileTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")
  }

  hideSelectedFile() {
    this.filenameTarget.textContent = ""

    this.selectedFileTarget.classList.add("hidden")

    this.emptyStateTarget.textContent = "Henüz dosya seçilmedi"

    this.emptyStateTarget.classList.remove(
      "hidden",
      "text-red-600"
    )

    this.emptyStateTarget.classList.add("text-gray-500")
  }

  showDragState() {
    this.dropzoneTarget.classList.remove(
      "border-gray-300",
      "bg-gray-50"
    )

    this.dropzoneTarget.classList.add(
      "border-blue-500",
      "bg-blue-50"
    )

    this.messageTarget.textContent =
      "Dosyayı buraya bırakın"

    this.iconTarget.textContent = "⬇️"
  }

  resetDropzone() {
    this.dropzoneTarget.classList.remove(
      "border-blue-500",
      "bg-blue-50"
    )

    this.dropzoneTarget.classList.add(
      "border-gray-300",
      "bg-gray-50"
    )

    this.messageTarget.textContent =
      "Dosyayı buraya sürükleyip bırak"

    this.iconTarget.textContent = "📄"
  }

  validFile(file) {
    const allowedTypes = [
      "application/pdf",
      "image/jpeg",
      "image/png"
    ]

    return allowedTypes.includes(file.type)
  }
}