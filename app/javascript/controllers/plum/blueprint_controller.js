import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "input"]
  static values = { types: Array, nestedTypes: Array, applyFieldsetUrl: String }

  connect() {
    this.syncFieldConfigVisibility()
    this.updateHiddenField()
  }

  addField(event) {
    event.preventDefault()

    const fieldHtml = `
      <div class="plum-blueprint-field" data-plum--blueprint-target="field">
        <div class="plum-blueprint-field-header col-span-full">
          <p class="plum-blueprint-field-title" data-field-summary>Untitled field<span class="plum-blueprint-field-type">text</span></p>
          <button type="button" data-action="plum--blueprint#removeField" class="text-sm font-medium text-red-600 hover:text-red-700">Remove</button>
        </div>
        <input type="text" placeholder="handle" data-field="handle"
               data-action="input->plum--blueprint#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <select data-field="type" data-action="change->plum--blueprint#inputChanged"
                class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
          ${this.typesValue.map(type => `<option value="${type.handle}">${type.label}</option>`).join("")}
        </select>
        <input type="text" placeholder="Label" data-field="label"
               data-action="input->plum--blueprint#inputChanged"
               class="px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 text-sm">
        <input type="text" placeholder="Related type handle" data-field="content_type" data-field-config="relationship"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <label class="hidden flex items-center gap-2 text-sm text-gray-700" data-field-config="relationship"><input type="checkbox" data-field="multiple" data-action="change->plum--blueprint#inputChanged"> Allow multiple entries</label>
        <input type="text" placeholder="Taxonomy handle" data-field="taxonomy" data-field-config="taxonomy"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm">
        <textarea rows="4" placeholder="Published | published&#10;Draft | draft" data-field="options" data-field-config="select radio button_group checkboxes"
               data-action="input->plum--blueprint#inputChanged"
               class="hidden col-span-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-purple-500 focus:border-purple-500 font-mono text-sm"></textarea>
        ${this.nestedEditorHtml()}
        ${this.typeConstraintsHtml()}
        <div class="col-span-full grid gap-3 border-t border-gray-200 pt-3 sm:grid-cols-3">
          <input type="text" placeholder="Instructions" data-field="instructions" data-action="input->plum--blueprint#inputChanged"
                 class="px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm">
          <input type="text" placeholder="Placeholder" data-field="placeholder" data-action="input->plum--blueprint#inputChanged"
                 class="px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm">
          <input type="text" placeholder="Default value" data-field="default" data-action="input->plum--blueprint#inputChanged"
                 class="px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm">
          <label class="flex items-center gap-2 text-sm text-gray-700">
            <input type="checkbox" data-field="required" data-action="change->plum--blueprint#inputChanged"> Required
          </label>
        </div>
        ${this.presentationHtml()}
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

  async applyFieldset(event) {
    event.preventDefault()
    const picker = this.element.querySelector("[data-fieldset-picker]")
    const status = this.element.querySelector("[data-fieldset-status]")
    if (!picker?.value || !this.hasApplyFieldsetUrlValue) return

    event.currentTarget.disabled = true
    if (status) {
      status.textContent = "Inserting…"
      status.className = "text-sm text-gray-600"
    }
    try {
      const response = await fetch(this.applyFieldsetUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ fieldset_id: picker.value })
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.error || "Could not insert fieldset")
      window.location.assign(payload.redirect_url)
    } catch (error) {
      event.currentTarget.disabled = false
      if (status) {
        status.textContent = error.message
        status.className = "text-sm text-red-600"
      }
    }
  }

  addNestedField(event) {
    event.preventDefault()
    const editor = event.currentTarget.closest("[data-nested-editor]")
    editor.querySelector("[data-nested-fields]").insertAdjacentHTML("beforeend", this.nestedFieldHtml())
    this.updateHiddenField()
  }

  removeNestedField(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-nested-field]").remove()
    this.updateHiddenField()
  }

  moveNestedField(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-nested-field]")
    const direction = Number(event.currentTarget.dataset.direction)
    const sibling = direction < 0 ? row.previousElementSibling : row.nextElementSibling
    if (!sibling) return
    if (direction < 0) row.parentElement.insertBefore(row, sibling)
    else row.parentElement.insertBefore(sibling, row)
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

        ;["instructions", "placeholder", "default", "number_kind", "step", "unit", "date_mode", "min_items", "max_items", "width"].forEach(key => {
          const value = fieldEl.querySelector(`[data-field="${key}"]`)?.value?.trim()
          if (value) field[key] = value
        })
        if (fieldEl.querySelector('[data-field="required"]')?.checked) field.required = true
        if (type === "relationship" && fieldEl.querySelector('[data-field="multiple"]')?.checked) field.multiple = true
        if (type === "list" && fieldEl.querySelector('[data-field="unique"]')?.checked) field.unique = true
        if (type === "number" || type === "date") {
          const constraints = fieldEl.querySelector(`[data-field-config="${type}"]`)
          ;["min", "max"].forEach(key => {
            const value = constraints?.querySelector(`[data-field="${key}"]`)?.value.trim()
            if (value) field[key] = value
          })
        }

        if (type === "relationship" && contentType) {
          field.content_type = contentType
        }

        const taxonomyVal = fieldEl.querySelector('[data-field="taxonomy"]')?.value?.trim()
        if (type === "taxonomy" && taxonomyVal) {
          field.taxonomy = taxonomyVal
        }

        const optionsVal = fieldEl.querySelector('[data-field="options"]')?.value?.trim()
        if (["select", "radio", "button_group", "checkboxes"].includes(type) && optionsVal) {
          field.options = optionsVal.split("\n").map(line => {
            const [label, ...valueParts] = line.split("|")
            const value = valueParts.join("|").trim()
            return value ? { label: label.trim(), value } : label.trim()
          }).filter(option => typeof option === "string" ? option : option.label && option.value)
        }

        const conditionField = fieldEl.querySelector('[data-field="condition_field"]')?.value.trim()
        const conditionOperator = fieldEl.querySelector('[data-field="condition_operator"]')?.value
        const conditionValue = fieldEl.querySelector('[data-field="condition_value"]')?.value.trim()
        if (conditionField && conditionOperator) {
          field.condition = { field: conditionField, operator: conditionOperator }
          if (conditionValue) field.condition.value = conditionValue
        }

        if (type === "group" || type === "repeater") {
          field.fields = this.readNestedFields(fieldEl)
        }

        fields.push(field)
      }
    })

    this.inputTarget.value = JSON.stringify({ fields })
  }

  readNestedFields(fieldEl) {
    return Array.from(fieldEl.querySelectorAll("[data-nested-field]")).filter(row => {
      return row.querySelector('[data-nested="handle"]')?.value.trim()
    }).map(row => {
      const handle = row.querySelector('[data-nested="handle"]').value.trim()
      const field = {
        handle,
        type: row.querySelector('[data-nested="type"]').value,
        label: row.querySelector('[data-nested="label"]').value.trim() || handle.replaceAll("_", " ")
      }
      ;["instructions", "placeholder", "default"].forEach(key => {
        const value = row.querySelector(`[data-nested="${key}"]`)?.value.trim()
        if (value) field[key] = value
      })
      if (row.querySelector('[data-nested="required"]')?.checked) field.required = true
      return field
    })
  }

  nestedEditorHtml() {
    return `<div class="hidden col-span-full space-y-3 rounded-md border border-gray-200 bg-white p-3" data-field-config="group repeater" data-nested-editor>
      <div class="flex items-center justify-between"><p class="text-sm font-medium text-gray-700">Nested fields</p>
      <button type="button" data-action="plum--blueprint#addNestedField" class="text-sm font-medium text-purple-600 hover:text-purple-700">+ Add nested field</button></div>
      <div class="space-y-3" data-nested-fields></div>
    </div>`
  }

  typeConstraintsHtml() {
    return `<div class="hidden col-span-full grid gap-3 rounded-md border border-gray-200 bg-white p-3 sm:grid-cols-4" data-field-config="number">
      <select data-field="number_kind" data-action="change->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm"><option value="decimal">Decimal</option><option value="integer">Integer</option></select>
      <input type="number" placeholder="Minimum" data-field="min" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="number" placeholder="Maximum" data-field="max" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="number" placeholder="Step" data-field="step" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="text" placeholder="Unit (optional)" data-field="unit" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
    </div>
    <div class="hidden col-span-full grid gap-3 rounded-md border border-gray-200 bg-white p-3 sm:grid-cols-3" data-field-config="date">
      <select data-field="date_mode" data-action="change->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm"><option value="date">Date</option><option value="time">Time</option><option value="datetime">Date and time</option></select>
      <input type="text" placeholder="Earliest value" data-field="min" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="text" placeholder="Latest value" data-field="max" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
    </div>
    <div class="hidden col-span-full grid gap-3 rounded-md border border-gray-200 bg-white p-3 sm:grid-cols-3" data-field-config="list repeater images relationship" data-multiple-only>
      <input type="number" min="0" placeholder="Minimum items" data-field="min_items" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="number" min="0" placeholder="Maximum items" data-field="max_items" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <label class="flex items-center gap-2 text-sm text-gray-700" data-field-config="list"><input type="checkbox" data-field="unique" data-action="change->plum--blueprint#inputChanged"> Unique values</label>
    </div>`
  }

  presentationHtml() {
    return `<div class="col-span-full grid gap-3 rounded-md border border-gray-200 bg-white p-3 sm:grid-cols-4">
      <select data-field="width" data-action="change->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
        <option value="12">Full width</option><option value="9">Three quarters</option><option value="8">Two thirds</option><option value="6">Half width</option><option value="4">One third</option><option value="3">Quarter width</option>
      </select>
      <input type="text" placeholder="Show when field…" data-field="condition_field" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 font-mono text-sm">
      <select data-field="condition_operator" data-action="change->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
        <option value="">No condition</option><option value="equals">Equals</option><option value="not_equals">Does not equal</option><option value="contains">Contains</option><option value="empty">Is empty</option><option value="not_empty">Is not empty</option>
      </select>
      <input type="text" placeholder="Value" data-field="condition_value" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
    </div>`
  }

  nestedFieldHtml() {
    const options = this.nestedTypesValue.map(type => `<option value="${type.handle}">${type.label}</option>`).join("")
    return `<div class="grid gap-2 rounded-md border border-gray-200 bg-gray-50 p-3 sm:grid-cols-3" data-nested-field>
      <input type="text" placeholder="handle" data-nested="handle" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 font-mono text-sm">
      <select data-nested="type" data-action="change->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">${options}</select>
      <input type="text" placeholder="Label" data-nested="label" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="text" placeholder="Instructions" data-nested="instructions" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="text" placeholder="Placeholder" data-nested="placeholder" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <input type="text" placeholder="Default value" data-nested="default" data-action="input->plum--blueprint#inputChanged" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
      <label class="flex items-center gap-2 text-sm text-gray-700"><input type="checkbox" data-nested="required" data-action="change->plum--blueprint#inputChanged"> Required</label>
      <div class="flex gap-3"><button type="button" data-direction="-1" data-action="plum--blueprint#moveNestedField" class="text-sm text-gray-600">↑ Up</button>
      <button type="button" data-direction="1" data-action="plum--blueprint#moveNestedField" class="text-sm text-gray-600">↓ Down</button>
      <button type="button" data-action="plum--blueprint#removeNestedField" class="text-sm font-medium text-red-600">Remove</button></div>
    </div>`
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
      const label = fieldEl.querySelector('[data-field="label"]')?.value.trim()
      const handle = fieldEl.querySelector('[data-field="handle"]')?.value.trim()
      const summary = fieldEl.querySelector("[data-field-summary]")
      if (summary) {
        summary.replaceChildren(document.createTextNode(label || handle || "Untitled field"))
        const typeLabel = document.createElement("span")
        typeLabel.className = "plum-blueprint-field-type"
        typeLabel.textContent = type || "text"
        summary.append(typeLabel)
      }
      fieldEl.querySelectorAll('[data-field-config]').forEach(configEl => {
        const configTypes = configEl.dataset.fieldConfig.split(" ")
        const multipleAllowed = !configEl.hasAttribute("data-multiple-only") || type !== "relationship" || fieldEl.querySelector('[data-field="multiple"]')?.checked
        configEl.classList.toggle("hidden", !configTypes.includes(type) || !multipleAllowed)
      })
    })
  }
}
