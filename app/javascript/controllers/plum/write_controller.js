import { Controller } from "@hotwired/stimulus"

// Distraction-free writing mode: autosaves the title and one rich text field
// a moment after typing stops, without leaving the page.
export default class extends Controller {
  static targets = ["form", "title", "editor", "status", "statusText", "words", "bar"]
  static values = { publishUrl: String }

  connect() {
    this.dirty = false
    this.saving = false
    this.resizeTitle()
    this.refreshWordCount()

    // Lexical swallows native input events, so "input" alone misses typing
    // in the body — lexxy:change is the editor's own any-edit signal.
    this.editorListener = () => this.contentChanged()
    this.editorTarget.addEventListener("lexxy:change", this.editorListener)
    this.editorTarget.addEventListener("input", this.editorListener)

    this.keyListener = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key === "s") {
        event.preventDefault()
        this.save()
      }
    }
    document.addEventListener("keydown", this.keyListener)

    // Flush pending edits when leaving instead of nagging with a dialog;
    // keepalive lets the request outlive the page. Only block navigation
    // when a save actually failed and edits would truly be lost.
    this.unloadListener = (event) => {
      if (!this.dirty) return
      this.flushSave()
      if (this.saveFailed) {
        event.preventDefault()
        event.returnValue = ""
      }
    }
    window.addEventListener("beforeunload", this.unloadListener)
  }

  disconnect() {
    this.editorTarget.removeEventListener("lexxy:change", this.editorListener)
    this.editorTarget.removeEventListener("input", this.editorListener)
    document.removeEventListener("keydown", this.keyListener)
    window.removeEventListener("beforeunload", this.unloadListener)
    clearTimeout(this.saveTimer)
  }

  titleChanged() {
    this.resizeTitle()
    this.contentChanged()
  }

  contentChanged() {
    this.dirty = true
    this.setStatus("dirty", "Unsaved changes")
    this.refreshWordCount()
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.save(), 2000)
  }

  // The top bar normally fades away; save activity has to be able to pull
  // it back so the state change is actually seen.
  setStatus(state, text) {
    this.statusTarget.dataset.state = state
    this.statusTextTarget.textContent = text

    clearTimeout(this.attentionTimer)
    if (state === "saving" || state === "error") {
      this.barTarget.classList.add("plum-write-bar--active")
    } else if (state === "saved") {
      this.barTarget.classList.add("plum-write-bar--active")
      this.attentionTimer = setTimeout(() => this.barTarget.classList.remove("plum-write-bar--active"), 1800)
    } else {
      this.barTarget.classList.remove("plum-write-bar--active")
    }
  }

  save() {
    if (this.saving) return this.savePromise
    this.savePromise = this.performSave()
    return this.savePromise
  }

  async performSave() {
    clearTimeout(this.saveTimer)
    this.saving = true
    this.dirty = false
    this.setStatus("saving", "Saving…")

    const hidden = document.getElementById(this.editorTarget.dataset.hiddenField)
    if (hidden) hidden.value = this.editorTarget.value

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        body: new FormData(this.formTarget),
        headers: { Accept: "application/json" }
      })
      const result = await response.json().catch(() => ({}))

      if (response.ok && result.saved) {
        const label = result.draft ? "Draft saved" : "Saved"
        this.setStatus("saved", `${label} at ${this.timeNow()}`)
        this.saveFailed = false
      } else {
        this.dirty = true
        this.saveFailed = true
        this.setStatus("error", (result.errors || ["Couldn't save"]).join(", "))
      }
    } catch {
      this.dirty = true
      this.saveFailed = true
      this.setStatus("error", "Offline — changes not saved yet")
    } finally {
      this.saving = false
    }
  }

  flushSave() {
    const hidden = document.getElementById(this.editorTarget.dataset.hiddenField)
    if (hidden) hidden.value = this.editorTarget.value
    this.dirty = false
    fetch(this.formTarget.action, {
      method: "POST",
      body: new FormData(this.formTarget),
      headers: { Accept: "application/json" },
      keepalive: true
    }).catch(() => {})
  }

  async publishDraft() {
    await this.save()
    if (this.dirty) return // the save failed; don't publish a stale draft

    this.setStatus("saving", "Publishing…")
    try {
      const response = await fetch(this.publishUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        }
      })
      if (response.ok) {
        this.setStatus("saved", `Published at ${this.timeNow()}`)
      } else {
        this.setStatus("error", "Couldn't publish")
      }
    } catch {
      this.setStatus("error", "Offline — couldn't publish")
    }
  }

  timeNow() {
    return new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
  }

  resizeTitle() {
    const title = this.titleTarget
    title.style.height = "auto"
    title.style.height = `${title.scrollHeight}px`
  }

  refreshWordCount() {
    const scratch = document.createElement("div")
    scratch.innerHTML = this.editorTarget.value || ""
    const text = scratch.textContent || ""
    const words = (text.trim().match(/\S+/g) || []).length
    this.wordsTarget.textContent = `${words} ${words === 1 ? "word" : "words"}`
  }
}
