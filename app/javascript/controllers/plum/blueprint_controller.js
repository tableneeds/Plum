import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "input"]

  connect() {
    this.updateHiddenField()
  }

  addField(event) {
    event.preventDefault()

    const fieldHtml = `
      <div class="flex items-center space-x-4 p-4 bg-gray-50 rounded-lg" data-plum--blueprint-target="field">
        <input type="text" placeholder="handle" data-field="handle"
               data-action="input->plum--blueprint#inputChanged"
               class="flex-1 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <select data-field="type" data-action="change->plum--blueprint#inputChanged"
                class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
          <option value="text">Text</option>
          <option value="textarea">Textarea</option>
          <option value="rich_text">Rich Text</option>
          <option value="number">Number</option>
          <option value="boolean">Boolean</option>
          <option value="date">Date</option>
          <option value="image">Image</option>
        </select>
        <input type="text" placeholder="Label" data-field="label"
               data-action="input->plum--blueprint#inputChanged"
               class="flex-1 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <button type="button" data-action="plum--blueprint#removeField" class="text-red-500 hover:text-red-700">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    `

    this.fieldsTarget.insertAdjacentHTML('beforeend', fieldHtml)
    this.updateHiddenField()
  }

  removeField(event) {
    event.preventDefault()
    const fieldDiv = event.currentTarget.closest('[data-plum--blueprint-target="field"]')
    fieldDiv.remove()
    this.updateHiddenField()
  }

  updateHiddenField() {
    const fields = []
    const fieldElements = this.fieldsTarget.querySelectorAll('[data-plum--blueprint-target="field"]')

    fieldElements.forEach(fieldEl => {
      const handle = fieldEl.querySelector('[data-field="handle"]')?.value
      const type = fieldEl.querySelector('[data-field="type"]')?.value
      const label = fieldEl.querySelector('[data-field="label"]')?.value

      if (handle) {
        fields.push({ handle, type, label })
      }
    })

    this.inputTarget.value = JSON.stringify({ fields })
  }

  inputChanged() {
    this.updateHiddenField()
  }
}
