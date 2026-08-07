import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count"]
  static values = { max: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    const selected = this.checkboxTargets.filter(checkbox => checkbox.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = `${selected} selected`
    this.checkboxTargets.forEach(checkbox => {
      checkbox.disabled = this.hasMaxValue && this.maxValue > 0 && selected >= this.maxValue && !checkbox.checked
    })
  }
}
