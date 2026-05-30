import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "panel"]

  connect() {
    this.update()
  }

  update() {
    const selectedHandle = this.selectTarget.value

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.getAttribute("data-plum--theme-settings-handle") !== selectedHandle
    })
  }
}
