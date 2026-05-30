import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Link from "@tiptap/extension-link"
import Placeholder from "@tiptap/extension-placeholder"

export default class extends Controller {
  static targets = ["editor", "input", "button"]

  connect() {
    this.inputTarget.hidden = true
    this.syncBeforeSubmit = this.syncBeforeSubmit.bind(this)
    this.inputTarget.form?.addEventListener("submit", this.syncBeforeSubmit)

    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit,
        Link.configure({
          autolink: true,
          openOnClick: false,
          HTMLAttributes: {
            rel: "noopener",
            target: "_blank"
          }
        }),
        Placeholder.configure({
          placeholder: "Start writing..."
        })
      ],
      content: this.inputTarget.value,
      editorProps: {
        attributes: {
          class: "plum-rich-text-content"
        }
      },
      onBlur: () => this.syncInput(),
      onSelectionUpdate: () => this.updateToolbar(),
      onUpdate: () => {
        this.syncInput()
        this.updateToolbar()
      }
    })

    this.updateToolbar()
  }

  disconnect() {
    this.inputTarget.form?.removeEventListener("submit", this.syncBeforeSubmit)
    this.editor?.destroy()
  }

  toggleBold() {
    this.editor.chain().focus().toggleBold().run()
  }

  toggleItalic() {
    this.editor.chain().focus().toggleItalic().run()
  }

  toggleHeading() {
    this.editor.chain().focus().toggleHeading({ level: 2 }).run()
  }

  toggleBulletList() {
    this.editor.chain().focus().toggleBulletList().run()
  }

  toggleOrderedList() {
    this.editor.chain().focus().toggleOrderedList().run()
  }

  toggleBlockquote() {
    this.editor.chain().focus().toggleBlockquote().run()
  }

  setLink() {
    const existingUrl = this.editor.getAttributes("link").href
    const url = window.prompt("URL", existingUrl || "https://")

    if (url === null) return

    if (url === "") {
      this.editor.chain().focus().extendMarkRange("link").unsetLink().run()
      return
    }

    this.editor.chain().focus().extendMarkRange("link").setLink({ href: url }).run()
  }

  unsetLink() {
    this.editor.chain().focus().extendMarkRange("link").unsetLink().run()
  }

  syncBeforeSubmit() {
    this.syncInput()
  }

  syncInput() {
    const html = this.editor.getHTML()
    this.inputTarget.value = html === "<p></p>" ? "" : html
  }

  updateToolbar() {
    this.buttonTargets.forEach((button) => {
      const command = button.dataset.command
      const active = this.buttonActive(command)

      button.setAttribute("aria-pressed", active ? "true" : "false")
      button.classList.toggle("bg-gray-900", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-gray-900", active)
    })
  }

  buttonActive(command) {
    switch (command) {
      case "bold":
        return this.editor.isActive("bold")
      case "italic":
        return this.editor.isActive("italic")
      case "heading":
        return this.editor.isActive("heading", { level: 2 })
      case "bulletList":
        return this.editor.isActive("bulletList")
      case "orderedList":
        return this.editor.isActive("orderedList")
      case "blockquote":
        return this.editor.isActive("blockquote")
      case "link":
        return this.editor.isActive("link")
      default:
        return false
    }
  }
}
