import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.refresh = this.refresh.bind(this)
    this.element.addEventListener("input", this.refresh)
    this.element.addEventListener("change", this.refresh)
    this.refresh()
  }

  disconnect() {
    this.element.removeEventListener("input", this.refresh)
    this.element.removeEventListener("change", this.refresh)
  }

  refresh() {
    this.element.querySelectorAll("[data-field-condition]").forEach(field => {
      const condition = JSON.parse(field.dataset.fieldCondition || "{}")
      const values = this.valuesFor(condition.field)
      const expected = String(condition.value ?? "")
      let visible = true

      if (condition.operator === "equals") visible = values.includes(expected)
      if (condition.operator === "not_equals") visible = !values.includes(expected)
      if (condition.operator === "contains") visible = values.some(value => value.includes(expected))
      if (condition.operator === "empty") visible = values.length === 0 || values.every(value => !value)
      if (condition.operator === "not_empty") visible = values.some(Boolean)

      field.classList.toggle("hidden", !visible)
      field.querySelectorAll("input, select, textarea, button").forEach(input => {
        if (input.type !== "hidden") input.disabled = !visible
      })
    })
  }

  valuesFor(handle) {
    if (!handle) return []
    const selector = `[name="entry[data][${CSS.escape(handle)}]"], [name="entry[data][${CSS.escape(handle)}][]"]`
    return Array.from(this.element.querySelectorAll(selector)).filter(input => {
      return !["checkbox", "radio"].includes(input.type) || input.checked
    }).map(input => input.value)
  }
}
