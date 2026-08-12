import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "selectAll"]

  connect() {
    this.updateSelectAll()
  }

  toggleAll() {
    this.providerTargets.forEach((checkbox) => {
      checkbox.checked = this.selectAllTarget.checked
    })
  }

  providerChanged() {
    this.updateSelectAll()
  }

  updateSelectAll() {
    const allSelected =
      this.providerTargets.length > 0 &&
      this.providerTargets.every((checkbox) => checkbox.checked)

    this.selectAllTarget.checked = allSelected
  }
}