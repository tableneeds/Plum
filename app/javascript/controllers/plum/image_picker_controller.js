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
  static targets = ["input", "preview", "panel", "grid", "file", "status"]
  static values = { assetsUrl: String, uploadUrl: String }

  connect() {
    this.assets = null
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
      this.setStatus("Could not load images.")
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
    btn.className = "group relative overflow-hidden rounded-md border border-gray-200 hover:border-purple-500 focus:border-purple-500 focus:outline-none"
    btn.title = asset.label || asset.filename
    btn.addEventListener("click", () => this.select(asset))

    const img = document.createElement("img")
    img.src = asset.url
    img.alt = asset.alt_text || ""
    img.className = "h-24 w-full object-cover"
    btn.appendChild(img)
    return btn
  }

  select(asset) {
    this.inputTarget.value = asset.id
    this.setPreview(asset.url, asset.alt_text)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  clear(event) {
    if (event) event.preventDefault()
    this.inputTarget.value = ""
    this.setPreview(null)
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  async upload(event) {
    const file = event.target.files && event.target.files[0]
    if (!file) return
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
      event.target.value = ""
    } catch (_e) {
      this.setStatus("Upload failed. Make sure it's an image.")
    }
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

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
