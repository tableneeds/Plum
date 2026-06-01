import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "input"]

  connect() {
    this.syncFieldConfigVisibility()
    this.updateHiddenField()
  }

  addField(event) {
    event.preventDefault()

    const fieldHtml = `
      <div class="grid grid-cols-1 gap-4 p-4 bg-gray-50 rounded-lg sm:grid-cols-2 lg:grid-cols-5" data-plum--blueprint-target="field">
        <input type="text" placeholder="handle" data-field="handle"
               data-action="input->plum--blueprint#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <select data-field="type" data-action="change->plum--blueprint#inputChanged"
                class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
          <option value="text">Text</option>
          <option value="textarea">Textarea</option>
          <option value="rich_text">Rich Text</option>
          <option value="number">Number</option>
          <option value="boolean">Boolean</option>
          <option value="date">Date</option>
          <option value="select">Select</option>
          <option value="checkboxes">Checkboxes</option>
          <option value="color">Color</option>
          <option value="url">URL</option>
          <option value="taxonomy">Taxonomy</option>
          <option value="image">Image</option>
          <option value="relationship">Relationship</option>
          <option value="blocks">Blocks</option>
        </select>
        <input type="text" placeholder="Label" data-field="label"
               data-action="input->plum--blueprint#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <input type="text" placeholder="Related type handle" data-field="content_type" data-field-config="relationship"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <input type="text" placeholder="Taxonomy handle" data-field="taxonomy" data-field-config="taxonomy"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <input type="text" placeholder="Option 1, Option 2, Option 3" data-field="options" data-field-config="select checkboxes"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <button type="button" data-action="plum--blueprint#removeField" class="justify-self-start text-red-500 hover:text-red-700">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    `

    this.fieldsTarget.insertAdjacentHTML('beforeend', fieldHtml)
    this.syncFieldConfigVisibility()
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
      const contentType = fieldEl.querySelector('[data-field="content_type"]')?.value?.trim()

      if (handle) {
        const field = { handle, type, label }

        if (type === "relationship" && contentType) {
          field.content_type = contentType
        }

        const taxonomyVal = fieldEl.querySelector('[data-field="taxonomy"]')?.value?.trim()
        if (type === "taxonomy" && taxonomyVal) {
          field.taxonomy = taxonomyVal
        }

        const optionsVal = fieldEl.querySelector('[data-field="options"]')?.value?.trim()
        if ((type === "select" || type === "checkboxes") && optionsVal) {
          field.options = optionsVal.split(",").map(o => o.trim()).filter(Boolean)
        }

        fields.push(field)
      }
    })

    this.inputTarget.value = JSON.stringify({ fields })
  }

  inputChanged(event) {
    const fieldEl = event.target.closest('[data-plum--blueprint-target="field"]')
    if (fieldEl) this.syncFieldConfigVisibility(fieldEl)

    this.updateHiddenField()
  }

  syncFieldConfigVisibility(fieldEl = null) {
    const fieldElements = fieldEl ? [fieldEl] : this.fieldsTarget.querySelectorAll('[data-plum--blueprint-target="field"]')

    fieldElements.forEach(fieldEl => {
      const type = fieldEl.querySelector('[data-field="type"]')?.value
      fieldEl.querySelectorAll('[data-field-config]').forEach(configEl => {
        const configTypes = configEl.dataset.fieldConfig.split(" ")
        configEl.classList.toggle("hidden", !configTypes.includes(type))
      })
    })
  }
}
