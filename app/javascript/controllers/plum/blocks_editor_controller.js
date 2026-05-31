import { Controller } from "@hotwired/stimulus"

// Minimal, dependency-free block editor for `blocks` fields.
// Phase B replaces this canvas with GrapesJS; the stored data contract
// (an array of { id, type, fields }) stays the same.
export default class extends Controller {
  static targets = ["input", "list", "picker"]
  static values = { definitions: Array }

  connect() {
    this.blocks = this.readInitial()
    this.render()
  }

  readInitial() {
    try {
      const parsed = JSON.parse(this.inputTarget.value || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch (_e) {
      return []
    }
  }

  definitionFor(type) {
    return this.definitionsValue.find((d) => d.handle === type)
  }

  add(event) {
    event.preventDefault()
    const type = this.hasPickerTarget ? this.pickerTarget.value : null
    if (!type) return
    this.blocks.push({ id: this.uuid(), type, fields: {} })
    this.render()
  }

  remove(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    this.blocks.splice(index, 1)
    this.render()
  }

  move(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    const delta = Number(event.currentTarget.dataset.delta)
    const target = index + delta
    if (target < 0 || target >= this.blocks.length) return
    const [item] = this.blocks.splice(index, 1)
    this.blocks.splice(target, 0, item)
    this.render()
  }

  fieldChanged(event) {
    const index = Number(event.currentTarget.dataset.index)
    const handle = event.currentTarget.dataset.field
    const block = this.blocks[index]
    if (!block) return
    block.fields = block.fields || {}
    block.fields[handle] = event.currentTarget.type === "checkbox"
      ? event.currentTarget.checked
      : event.currentTarget.value
    this.serialize()
  }

  serialize() {
    this.inputTarget.value = JSON.stringify(this.blocks)
  }

  render() {
    this.serialize()
    this.listTarget.innerHTML = ""
    this.blocks.forEach((block, index) => {
      this.listTarget.appendChild(this.cardFor(block, index))
    })
  }

  cardFor(block, index) {
    const def = this.definitionFor(block.type) || { label: block.type, fields: [] }
    const card = document.createElement("div")
    card.className = "rounded-lg border border-gray-200 bg-gray-50 p-4 space-y-3"

    const header = document.createElement("div")
    header.className = "flex items-center justify-between"

    const title = document.createElement("span")
    title.className = "text-sm font-semibold text-gray-700"
    title.textContent = def.label || block.type
    header.appendChild(title)

    const controls = document.createElement("div")
    controls.className = "flex items-center gap-3"
    controls.appendChild(this.button("Up", { index, delta: -1 }, "move"))
    controls.appendChild(this.button("Down", { index, delta: 1 }, "move"))
    controls.appendChild(this.button("Remove", { index }, "remove", "text-red-600"))
    header.appendChild(controls)
    card.appendChild(header)

    ;(def.fields || []).forEach((fieldDef) => {
      card.appendChild(this.fieldFor(fieldDef, block, index))
    })

    return card
  }

  fieldFor(fieldDef, block, index) {
    const wrapper = document.createElement("div")
    wrapper.className = "space-y-1"

    const label = document.createElement("label")
    label.className = "block text-xs font-medium text-gray-600"
    label.textContent = fieldDef.label || fieldDef.handle
    wrapper.appendChild(label)

    const stored = (block.fields && block.fields[fieldDef.handle])
    const value = stored === undefined || stored === null ? "" : stored
    const baseClass = "block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500"

    let input
    switch (fieldDef.type) {
      case "textarea":
      case "rich_text":
        input = document.createElement("textarea")
        input.rows = 4
        input.className = baseClass
        input.value = value
        break
      case "boolean":
        input = document.createElement("input")
        input.type = "checkbox"
        input.checked = value === true || value === "true"
        break
      case "select":
        input = document.createElement("select")
        input.className = baseClass
        ;(fieldDef.options || []).forEach((opt) => {
          const option = document.createElement("option")
          const optionValue = typeof opt === "object" ? opt.value : opt
          option.value = optionValue
          option.textContent = typeof opt === "object" ? opt.label : opt
          if (String(optionValue) === String(value)) option.selected = true
          input.appendChild(option)
        })
        break
      case "date":
        input = document.createElement("input")
        input.type = "date"
        input.className = baseClass
        input.value = value
        break
      default:
        input = document.createElement("input")
        input.type = "text"
        input.className = baseClass
        input.value = value
    }

    input.dataset.index = index
    input.dataset.field = fieldDef.handle
    input.dataset.action = "input->plum--blocks-editor#fieldChanged change->plum--blocks-editor#fieldChanged"
    wrapper.appendChild(input)

    if (fieldDef.type === "image") {
      const help = document.createElement("p")
      help.className = "text-xs text-gray-400"
      help.textContent = "Asset ID"
      wrapper.appendChild(help)
    }

    return wrapper
  }

  button(text, data, action, extra = "") {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = `text-xs text-gray-600 hover:text-gray-900 ${extra}`.trim()
    btn.textContent = text
    Object.entries(data).forEach(([key, val]) => { btn.dataset[key] = val })
    btn.dataset.action = `plum--blocks-editor#${action}`
    return btn
  }

  uuid() {
    if (window.crypto && window.crypto.randomUUID) return window.crypto.randomUUID()
    return `b-${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`
  }
}
