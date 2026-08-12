import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.timer = setInterval(() => {
      Turbo.visit(window.location.href, {
        action: "replace"
      })
    }, this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}