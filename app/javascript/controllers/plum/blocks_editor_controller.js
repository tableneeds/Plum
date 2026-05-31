import { Controller } from "@hotwired/stimulus"

// Plum's own simple block editor (no GrapesJS).
//
// A calm vertical list of block "cards" — add, reorder, remove — each showing
// its theme-declared fields as plain inputs. The block library comes from the
// active theme via Plum::BlockEditorConfig (configValue); the editor never reads
// a theme directly. The stored value is the canonical ordered array of
// { id, type, fields }, persisted as JSON in the hidden input.
export default class extends Controller {
  static targets = ["input", "list", "picker", "empty"]
  static values = { config: Object }

  connect() {
    this.defs = this.configValue.blocks || []
    this.defsByType = Object.fromEntries(this.defs.map((d) => [d.id, d]))
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

  add(event) {
    event.preventDefault()
    const type = this.hasPickerTarget ? this.pickerTarget.value : this.defs[0]?.id
    if (!type || !this.defsByType[type]) return
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
    const target = index + Number(event.currentTarget.dataset.delta)
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
    this.blocks.forEach((block, index) => this.listTarget.appendChild(this.card(block, index)))
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", this.blocks.length > 0)
  }

  card(block, index) {
    const def = this.defsByType[block.type] || { label: block.type, fields: [] }
    const card = document.createElement("div")
    card.className = "rounded-lg border border-gray-200 bg-white shadow-sm"

    const header = document.createElement("div")
    header.className = "flex items-center justify-between border-b border-gray-100 px-4 py-2.5"
    const title = document.createElement("span")
    title.className = "text-sm font-semibold text-gray-800"
    title.textContent = def.label || block.type
    header.appendChild(title)

    const controls = document.createElement("div")
    controls.className = "flex items-center gap-1"
    controls.appendChild(this.iconButton("↑", "move", { index, delta: -1 }, index === 0))
    controls.appendChild(this.iconButton("↓", "move", { index, delta: 1 }, index === this.blocks.length - 1))
    controls.appendChild(this.iconButton("Remove", "remove", { index }, false, "text-red-600 hover:text-red-700"))
    header.appendChild(controls)
    card.appendChild(header)

    const body = document.createElement("div")
    body.className = "space-y-3 px-4 py-3"
    if ((def.fields || []).length === 0) {
      const none = document.createElement("p")
      none.className = "text-sm text-gray-400"
      none.textContent = "This block has no editable fields."
      body.appendChild(none)
    }
    ;(def.fields || []).forEach((f) => body.appendChild(this.field(f, block, index)))
    card.appendChild(body)
    return card
  }

  field(fieldDef, block, index) {
    const wrap = document.createElement("label")
    wrap.className = "block space-y-1"
    const label = document.createElement("span")
    label.className = "block text-xs font-medium text-gray-600"
    label.textContent = fieldDef.label || fieldDef.handle
    wrap.appendChild(label)

    const stored = block.fields ? block.fields[fieldDef.handle] : undefined
    const value = stored === undefined || stored === null ? "" : stored
    const cls = "block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-purple-500 focus:outline-none focus:ring-purple-500"

    let input
    switch (fieldDef.type) {
      case "textarea":
      case "rich_text":
        input = document.createElement("textarea")
        input.rows = 4
        input.className = cls
        input.value = value
        break
      case "boolean":
        input = document.createElement("input")
        input.type = "checkbox"
        input.checked = value === true || value === "true"
        break
      case "select":
        input = document.createElement("select")
        input.className = cls
        ;(fieldDef.options || []).forEach((o) => {
          const opt = document.createElement("option")
          const v = typeof o === "object" ? o.value : o
          opt.value = v
          opt.textContent = typeof o === "object" ? o.label : o
          if (String(v) === String(value)) opt.selected = true
          input.appendChild(opt)
        })
        break
      case "date":
        input = document.createElement("input")
        input.type = "date"
        input.className = cls
        input.value = value
        break
      default:
        input = document.createElement("input")
        input.type = "text"
        input.className = cls
        input.value = value
    }

    input.dataset.index = index
    input.dataset.field = fieldDef.handle
    input.dataset.action = "input->plum--blocks-editor#fieldChanged change->plum--blocks-editor#fieldChanged"

    if (fieldDef.type === "image") {
      const hint = document.createElement("span")
      hint.className = "block text-xs text-gray-400"
      hint.textContent = "Asset ID (a full image picker comes later)"
      wrap.appendChild(input)
      wrap.appendChild(hint)
      return wrap
    }

    wrap.appendChild(input)
    return wrap
  }

  iconButton(text, action, data, disabled, extra = "") {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.disabled = disabled
    btn.className = `rounded px-2 py-1 text-xs font-medium text-gray-500 hover:bg-gray-100 disabled:opacity-30 ${extra}`.trim()
    btn.textContent = text
    Object.entries(data).forEach(([k, v]) => { btn.dataset[k] = v })
    btn.dataset.action = `plum--blocks-editor#${action}`
    return btn
  }

  uuid() {
    if (window.crypto && window.crypto.randomUUID) return window.crypto.randomUUID()
    return `b-${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`
  }
}
