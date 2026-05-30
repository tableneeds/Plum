import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "input"]

  connect() {
    this.updateHiddenField()
  }

  addField(event) {
    event.preventDefault()

    this.fieldsTarget.insertAdjacentHTML("beforeend", this.fieldHtml())
    this.updateHiddenField()
  }

  removeField(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-plum--form-fields-target='field']").remove()
    this.updateHiddenField()
  }

  inputChanged() {
    this.updateHiddenField()
  }

  updateHiddenField() {
    const fields = []
    const fieldElements = this.fieldsTarget.querySelectorAll("[data-plum--form-fields-target='field']")

    fieldElements.forEach((fieldEl) => {
      const handle = fieldEl.querySelector("[data-field='handle']")?.value
      const type = fieldEl.querySelector("[data-field='type']")?.value
      const label = fieldEl.querySelector("[data-field='label']")?.value
      const required = fieldEl.querySelector("[data-field='required']")?.checked
      const options = fieldEl.querySelector("[data-field='options']")?.value

      if (handle) {
        fields.push({
          handle,
          type,
          label,
          required,
          options: options ? options.split(",").map((option) => option.trim()).filter(Boolean) : []
        })
      }
    })

    this.inputTarget.value = JSON.stringify({ fields })
  }

  fieldHtml() {
    return `
      <div class="grid grid-cols-1 gap-4 p-4 bg-gray-50 rounded-lg sm:grid-cols-2" data-plum--form-fields-target="field">
        <input type="text" placeholder="handle" data-field="handle"
               data-action="input->plum--form-fields#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <input type="text" placeholder="Label" data-field="label"
               data-action="input->plum--form-fields#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <select data-field="type" data-action="change->plum--form-fields#inputChanged"
                class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
          <option value="text">Text</option>
          <option value="email">Email</option>
          <option value="textarea">Textarea</option>
          <option value="select">Select</option>
          <option value="checkbox">Checkbox</option>
        </select>
        <input type="text" placeholder="Options, comma-separated" data-field="options"
               data-action="input->plum--form-fields#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" data-field="required" data-action="change->plum--form-fields#inputChanged"
                 class="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500">
          Required
        </label>
        <button type="button" data-action="plum--form-fields#removeField"
                class="justify-self-start text-sm font-medium text-red-700 hover:text-red-700">
          Remove
        </button>
      </div>
    `
  }
}
