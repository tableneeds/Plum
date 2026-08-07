import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "rows", "empty", "add"]
  static values = { type: String, fields: Array, minItems: Number, maxItems: Number }

  connect() {
    this.value = this.read()
    this.render()
  }

  add(event) {
    event.preventDefault()
    if (this.hasMaxItemsValue && this.value.length >= this.maxItemsValue) return
    this.value.push(this.typeValue === "list" ? "" : {})
    this.render()
  }

  remove(event) {
    event.preventDefault()
    if (this.hasMinItemsValue && this.value.length <= this.minItemsValue) return
    this.value.splice(Number(event.currentTarget.dataset.index), 1)
    this.render()
  }

  move(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    const target = index + Number(event.currentTarget.dataset.direction)
    if (target < 0 || target >= this.value.length) return
    const [row] = this.value.splice(index, 1)
    this.value.splice(target, 0, row)
    this.render()
  }

  changed(event) {
    const index = Number(event.currentTarget.dataset.index)
    const field = event.currentTarget.dataset.field
    const value = event.currentTarget.type === "checkbox" ? event.currentTarget.checked : event.currentTarget.value
    if (this.typeValue === "list") this.value[index] = value
    else this.value[index][field] = value
    this.serialize()
  }

  read() {
    try {
      const parsed = JSON.parse(this.inputTarget.value || (this.typeValue === "group" ? "{}" : "[]"))
      if (this.typeValue === "group") return [parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {}]
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return this.typeValue === "group" ? [{}] : []
    }
  }

  serialize() {
    this.inputTarget.value = JSON.stringify(this.typeValue === "group" ? (this.value[0] || {}) : this.value)
  }

  render() {
    this.rowsTarget.innerHTML = ""
    this.value.forEach((row, index) => this.rowsTarget.appendChild(this.row(row, index)))
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", this.value.length > 0)
    if (this.hasAddTarget) this.addTarget.disabled = this.hasMaxItemsValue && this.value.length >= this.maxItemsValue
    this.serialize()
  }

  row(row, index) {
    const wrapper = document.createElement("div")
    wrapper.className = "space-y-3 rounded-lg border border-gray-200 bg-gray-50 p-4"

    const fields = this.typeValue === "list" ? [{ handle: "value", label: "Value", type: "text" }] : this.fieldsValue
    fields.forEach(field => wrapper.appendChild(this.control(field, row, index)))

    if (this.typeValue !== "group") {
      const controls = document.createElement("div")
      controls.className = "flex items-center gap-3"
      controls.appendChild(this.actionButton("↑ Up", "move", index, { direction: -1, disabled: index === 0 }))
      controls.appendChild(this.actionButton("↓ Down", "move", index, { direction: 1, disabled: index === this.value.length - 1 }))
      const remove = document.createElement("button")
      remove.type = "button"
      remove.textContent = "Remove"
      remove.dataset.index = index
      remove.dataset.action = "plum--structured-field#remove"
      remove.disabled = this.hasMinItemsValue && this.value.length <= this.minItemsValue
      remove.className = "text-sm font-medium text-red-600 hover:text-red-700 disabled:opacity-30"
      controls.appendChild(remove)
      wrapper.appendChild(controls)
    }
    return wrapper
  }

  actionButton(label, action, index, options = {}) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = label
    button.dataset.index = index
    button.dataset.action = `plum--structured-field#${action}`
    if (options.direction) button.dataset.direction = options.direction
    button.disabled = options.disabled || false
    button.className = "text-sm text-gray-600 hover:text-gray-900 disabled:opacity-30"
    return button
  }

  control(field, row, index) {
    const label = document.createElement("label")
    label.className = "block space-y-1"
    const caption = document.createElement("span")
    caption.className = "block text-xs font-medium text-gray-600"
    caption.textContent = field.label || field.handle
    label.appendChild(caption)
    if (field.instructions) {
      const instructions = document.createElement("span")
      instructions.className = "block text-xs text-gray-500"
      instructions.textContent = field.instructions
      label.appendChild(instructions)
    }

    const input = field.type === "textarea" ? document.createElement("textarea") : document.createElement("input")
    if (field.type !== "textarea") input.type = field.type === "boolean" ? "checkbox" : (field.type === "number" ? "number" : field.type === "date" ? "date" : "text")
    const stored = this.typeValue === "list" ? row : row?.[field.handle]
    const value = stored === undefined || stored === null ? field.default : stored
    if (input.type === "checkbox") input.checked = value === true || value === "true"
    else input.value = value ?? ""
    if (input.type !== "checkbox") input.className = "block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm"
    if (field.placeholder) input.placeholder = field.placeholder
    input.required = field.required === true || field.required === "true"
    input.dataset.index = index
    input.dataset.field = field.handle
    input.dataset.action = "input->plum--structured-field#changed change->plum--structured-field#changed"
    label.appendChild(input)
    return label
  }
}
