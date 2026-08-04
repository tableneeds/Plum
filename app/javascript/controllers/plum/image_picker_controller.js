import { Controller } from "@hotwired/stimulus"

// Reusable image picker. Stores the chosen asset's id in a hidden input and
// shows a thumbnail preview. "Choose image" opens an inline panel with a grid
// of the site's assets plus an inline uploader. Works both when rendered from
// ERB (entry image fields) and when injected by the block editor's JS.
//
// data values:
//   assetsUrl  - GET (json) list of assets [{id,url,filename,folder,alt_text,label}]
//   uploadUrl  - POST (multipart, json) to create an asset, returns the asset json
//   value      - initially selected asset id (optional)
export default class extends Controller {
  static targets = ["input", "preview", "panel", "grid", "file", "status", "filename", "dropzone", "saveButton", "saveStatus"]
  static values = { assetsUrl: String, uploadUrl: String, saveUrl: String, fieldHandle: String }

  connect() {
    this.assets = null
    this.dragDepth = 0
    if (this.inputTarget.value) this.refreshPreviewFromList()
  }

  toggle(event) {
    event.preventDefault()
    this.panelTarget.classList.toggle("hidden")
    if (!this.panelTarget.classList.contains("hidden")) this.load()
  }

  close(event) {
    if (event) event.preventDefault()
    this.panelTarget.classList.add("hidden")
  }

  async load() {
    if (this.assets) return
    this.setStatus("Loading…")
    try {
      const res = await fetch(this.assetsUrlValue, { headers: { Accept: "application/json" } })
      this.assets = await res.json()
      this.renderGrid()
      this.setStatus("")
    } catch (_e) {
      this.setStatus("Could not load images.", true)
    }
  }

  renderGrid() {
    this.gridTarget.innerHTML = ""
    if (!this.assets.length) {
      this.setStatus("No images yet — upload one below.")
      return
    }
    this.assets.forEach((asset) => this.gridTarget.appendChild(this.thumb(asset)))
  }

  thumb(asset) {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "group relative aspect-square cursor-pointer overflow-hidden rounded-lg border border-gray-200 bg-gray-50 shadow-sm transition-shadow hover:border-purple-500 hover:shadow-md focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
    btn.title = asset.label || asset.filename
    btn.addEventListener("click", () => this.select(asset))

    const img = document.createElement("img")
    img.src = asset.url
    img.alt = asset.alt_text || ""
    img.className = "h-full w-full object-cover"
    btn.appendChild(img)
    return btn
  }

  select(asset) {
    this.inputTarget.value = asset.id
    this.setPreview(asset.url, asset.alt_text)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.markUnsaved()
    this.close()
  }

  async clear(event) {
    if (event) event.preventDefault()
    if (this.inputTarget.value && !window.confirm("Remove this image? This change will be saved immediately.")) return
    this.inputTarget.value = ""
    this.setPreview(null)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    if (this.hasSaveUrlValue) await this.saveRemoval()
    else this.markUnsaved()
  }

  async save(event) {
    event.preventDefault()
    if (!this.hasSaveUrlValue || !this.hasSaveButtonTarget) return

    const assetId = this.inputTarget.value
    this.setSaveState("saving")

    try {
      await this.persistAssetId(assetId)

      if (this.inputTarget.value === assetId) this.setSaveState("saved")
      else this.markUnsaved()
    } catch (error) {
      this.setSaveState("error", error.message)
    }
  }

  async saveRemoval() {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.classList.add("hidden")
      this.saveButtonTarget.disabled = true
    }
    this.showSaveStatus("Removing image…", "text-gray-600")

    try {
      await this.persistAssetId("")
      this.showSaveStatus("Image removed without changing your other edits.", "text-green-700")
    } catch (error) {
      this.setSaveState("error", error.message)
    }
  }

  async persistAssetId(assetId) {
    const res = await fetch(this.saveUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({ field_handle: this.fieldHandleValue, asset_id: assetId || null })
    })
    const payload = await res.json().catch(() => ({}))
    if (!res.ok) throw new Error(payload.error || "Could not save image")
    return payload
  }

  markUnsaved() {
    if (!this.hasSaveButtonTarget) return
    this.saveButtonTarget.classList.remove("hidden")
    this.saveButtonTarget.disabled = false
    this.saveButtonTarget.textContent = "Save image"
    this.showSaveStatus("Image change not saved", "text-amber-700")
  }

  setSaveState(state, message = "") {
    if (!this.hasSaveButtonTarget) return
    if (state === "saving") {
      this.saveButtonTarget.classList.remove("hidden")
      this.saveButtonTarget.disabled = true
      this.saveButtonTarget.textContent = "Saving…"
      this.showSaveStatus("Saving image…", "text-gray-600")
    } else if (state === "saved") {
      this.saveButtonTarget.disabled = true
      this.saveButtonTarget.textContent = "Image saved"
      this.saveButtonTarget.classList.add("hidden")
      this.showSaveStatus("Image saved without changing your other edits.", "text-green-700")
    } else {
      this.saveButtonTarget.classList.remove("hidden")
      this.saveButtonTarget.disabled = false
      this.saveButtonTarget.textContent = "Try again"
      this.showSaveStatus(message || "Could not save image.", "text-red-700")
    }
  }

  showSaveStatus(message, colorClass) {
    if (!this.hasSaveStatusTarget) return
    this.saveStatusTarget.textContent = message
    this.saveStatusTarget.classList.remove("hidden", "text-amber-700", "text-gray-600", "text-green-700", "text-red-700")
    this.saveStatusTarget.classList.add(colorClass)
  }

  async upload(event) {
    const file = event.target.files && event.target.files[0]
    if (!file) return
    await this.uploadFile(file)
    event.target.value = ""
  }

  dragenter(event) {
    event.preventDefault()
    this.dragDepth += 1
    this.setDropzoneActive(true)
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  dragleave(event) {
    event.preventDefault()
    this.dragDepth = Math.max(0, this.dragDepth - 1)
    if (this.dragDepth === 0) this.setDropzoneActive(false)
  }

  async drop(event) {
    event.preventDefault()
    this.dragDepth = 0
    this.setDropzoneActive(false)
    const file = event.dataTransfer.files && event.dataTransfer.files[0]
    if (!file) return
    await this.uploadFile(file)
  }

  async uploadFile(file) {
    if (!file.type.startsWith("image/")) {
      this.setStatus("Upload failed. Choose an image file.", true)
      return
    }
    if (this.hasFilenameTarget) this.filenameTarget.textContent = file.name
    this.setStatus("Uploading…")
    const body = new FormData()
    body.append("asset[file]", file)
    try {
      const res = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() },
        body
      })
      if (!res.ok) throw new Error("upload failed")
      const asset = await res.json()
      if (this.assets) this.assets.unshift(asset)
      this.select(asset)
      this.setStatus("")
      if (this.hasFilenameTarget) this.filenameTarget.textContent = "Drag and drop, or click to browse · PNG, JPG, GIF, or WebP"
    } catch (_e) {
      this.setStatus("Upload failed. Make sure it's an image.", true)
    }
  }

  setDropzoneActive(active) {
    if (!this.hasDropzoneTarget) return
    this.dropzoneTarget.classList.toggle("border-purple-500", active)
    this.dropzoneTarget.classList.toggle("bg-purple-50", active)
    this.dropzoneTarget.classList.toggle("ring-2", active)
    this.dropzoneTarget.classList.toggle("ring-purple-500", active)
  }

  refreshPreviewFromList() {
    // We have an id but not the URL (e.g. block editor restore). Fetch the list
    // once to resolve the preview.
    fetch(this.assetsUrlValue, { headers: { Accept: "application/json" } })
      .then((res) => res.json())
      .then((assets) => {
        this.assets = assets
        const current = assets.find((a) => String(a.id) === String(this.inputTarget.value))
        if (current) this.setPreview(current.url, current.alt_text)
      })
      .catch(() => {})
  }

  setPreview(url, alt = "") {
    if (!this.hasPreviewTarget) return
    if (url) {
      this.previewTarget.innerHTML = ""
      const img = document.createElement("img")
      img.src = url
      img.alt = alt || ""
      img.className = "rounded-md object-contain"
      img.style.cssText = "max-height: 8rem; max-width: 16rem;"
      this.previewTarget.appendChild(img)
    } else {
      this.previewTarget.innerHTML = '<div class="flex h-32 w-full items-center justify-center rounded-md border border-dashed border-gray-300 text-sm text-gray-400">No image selected</div>'
    }
  }

  setStatus(text, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("hidden", !text)
    this.statusTarget.classList.toggle("border-red-200", isError)
    this.statusTarget.classList.toggle("bg-red-50", isError)
    this.statusTarget.classList.toggle("text-red-700", isError)
    this.statusTarget.classList.toggle("border-gray-200", !isError)
    this.statusTarget.classList.toggle("bg-gray-50", !isError)
    this.statusTarget.classList.toggle("text-gray-600", !isError)
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
