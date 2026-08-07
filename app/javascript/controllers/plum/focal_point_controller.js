import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "x", "y", "label"]

  connect() {
    this.refresh()
  }

  refresh() {
    const x = this.xTarget.value
    const y = this.yTarget.value
    if (this.hasPreviewTarget) this.previewTarget.style.objectPosition = `${x}% ${y}%`
    if (this.hasLabelTarget) this.labelTarget.textContent = `${x}% × ${y}%`
  }
}
