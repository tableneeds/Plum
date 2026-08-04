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
  static values = { config: Object, assetsUrl: String, uploadUrl: String }

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
    const stored = block.fields ? block.fields[fieldDef.handle] : undefined
    const value = stored === undefined || stored === null ? "" : stored

    if (fieldDef.type === "image" && this.hasAssetsUrlValue) {
      return this.imagePickerField(fieldDef, index, value)
    }

    const wrap = document.createElement("label")
    wrap.className = "block space-y-1"
    const label = document.createElement("span")
    label.className = "block text-xs font-medium text-gray-600"
    label.textContent = fieldDef.label || fieldDef.handle
    wrap.appendChild(label)

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

    wrap.appendChild(input)
    return wrap
  }

  // Builds a nested plum--image-picker for an image block field. The picker's
  // hidden input doubles as this block editor's field input (it carries the
  // data-index/data-field/data-action so selecting an asset updates the block).
  imagePickerField(fieldDef, index, value) {
    // NOTE: data-* attributes with dashes/colons (Stimulus target/value names)
    // must be set via setAttribute — assigning through element.dataset[...] with
    // such keys throws a SyntaxError.
    const wrap = document.createElement("div")
    wrap.className = "space-y-3"
    wrap.setAttribute("data-controller", "plum--image-picker")
    wrap.setAttribute("data-plum--image-picker-assets-url-value", this.assetsUrlValue)
    wrap.setAttribute("data-plum--image-picker-upload-url-value", this.uploadUrlValue)

    const label = document.createElement("span")
    label.className = "block text-xs font-medium text-gray-600"
    label.textContent = fieldDef.label || fieldDef.handle
    wrap.appendChild(label)

    const input = document.createElement("input")
    input.type = "hidden"
    input.value = value
    input.setAttribute("data-plum--image-picker-target", "input")
    // The image picker (a separate, nested controller) updates this hidden input
    // and dispatches input/change. We listen DIRECTLY rather than via a Stimulus
    // data-action so the update is captured reliably regardless of cross-controller
    // routing. The closure captures the current index/handle (recreated on render).
    const persist = () => {
      const block = this.blocks[index]
      if (!block) return
      block.fields = block.fields || {}
      block.fields[fieldDef.handle] = input.value
      this.serialize()
    }
    input.addEventListener("input", persist)
    input.addEventListener("change", persist)
    wrap.appendChild(input)

    const preview = document.createElement("div")
    preview.setAttribute("data-plum--image-picker-target", "preview")
    wrap.appendChild(preview)

    const controls = document.createElement("div")
    controls.className = "flex flex-wrap items-center gap-3"
    controls.appendChild(this.pickerButton("Choose image", "toggle", "inline-flex cursor-pointer items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"))
    controls.appendChild(this.pickerButton("Remove", "clear", "rounded-md px-2 py-2 text-sm font-medium text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700"))
    wrap.appendChild(controls)

    const panel = document.createElement("div")
    panel.className = "hidden overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm"
    panel.setAttribute("data-plum--image-picker-target", "panel")

    const header = document.createElement("div")
    header.className = "flex items-center justify-between border-b border-gray-200 px-4 py-3"
    header.innerHTML = '<div><p class="text-sm font-semibold text-gray-900">Image library</p><p class="text-xs text-gray-500">Select an existing image or upload a new one.</p></div>'
    header.appendChild(this.pickerButton("Close", "close", "rounded-md px-2 py-1 text-sm font-medium text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700"))
    panel.appendChild(header)

    const status = document.createElement("p")
    status.className = "hidden border-b px-4 py-2 text-sm font-medium"
    status.setAttribute("role", "status")
    status.setAttribute("data-plum--image-picker-target", "status")
    panel.appendChild(status)

    const grid = document.createElement("div")
    grid.className = "grid grid-cols-2 gap-3 p-4 sm:grid-cols-4"
    grid.setAttribute("data-plum--image-picker-target", "grid")
    panel.appendChild(grid)

    const uploadWrap = document.createElement("div")
    uploadWrap.className = "border-t border-gray-200 bg-gray-50 px-4 py-4"
    const uploadHeading = document.createElement("p")
    uploadHeading.className = "mb-2 text-sm font-semibold text-gray-700"
    uploadHeading.textContent = "Upload a new image"
    const file = document.createElement("input")
    file.type = "file"
    file.accept = "image/*"
    file.className = "peer sr-only"
    file.setAttribute("data-plum--image-picker-target", "file")
    file.setAttribute("data-action", "change->plum--image-picker#upload")
    file.id = `block-image-upload-${index}-${fieldDef.handle}`
    const uploadLabel = document.createElement("label")
    uploadLabel.htmlFor = file.id
    uploadLabel.setAttribute("data-plum--image-picker-target", "dropzone")
    uploadLabel.setAttribute("data-action", "dragenter->plum--image-picker#dragenter dragover->plum--image-picker#dragover dragleave->plum--image-picker#dragleave drop->plum--image-picker#drop")
    uploadLabel.className = "flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-gray-300 bg-white px-6 py-6 text-center transition-colors hover:border-purple-400 hover:bg-purple-50 peer-focus:ring-2 peer-focus:ring-purple-500 peer-focus:ring-offset-2"
    uploadLabel.innerHTML = '<span class="mb-3 flex h-10 w-10 items-center justify-center rounded-full bg-purple-100 text-purple-600" aria-hidden="true"><svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a1 1 0 0 1 1 1v6.59l2.3-2.3a1 1 0 1 1 1.4 1.42l-4 4a1 1 0 0 1-1.4 0l-4-4A1 1 0 0 1 6.7 7.3L9 9.59V3a1 1 0 0 1 1-1Z"/><path d="M3 13a1 1 0 0 1 1 1v2h12v-2a1 1 0 1 1 2 0v2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-2a1 1 0 0 1 1-1Z"/></svg></span><span class="text-sm font-semibold text-purple-600">Choose an image</span><span class="mt-1 text-xs text-gray-500" data-plum--image-picker-target="filename">Drag and drop, or click to browse · PNG, JPG, GIF, or WebP</span>'
    uploadWrap.appendChild(uploadHeading)
    uploadWrap.appendChild(file)
    uploadWrap.appendChild(uploadLabel)
    panel.appendChild(uploadWrap)

    wrap.appendChild(panel)
    return wrap
  }

  pickerButton(text, action, className) {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = `${className} cursor-pointer`
    btn.textContent = text
    btn.dataset.action = `plum--image-picker#${action}`
    return btn
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
