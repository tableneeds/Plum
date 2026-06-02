import "lexxy"

document.addEventListener("turbo:submit-start", (event) => {
  event.target.querySelectorAll("lexxy-editor[data-hidden-field]").forEach((editor) => {
    const hidden = document.getElementById(editor.dataset.hiddenField)
    if (hidden) hidden.value = editor.value
  })
})

document.addEventListener("submit", (event) => {
  event.target.querySelectorAll("lexxy-editor[data-hidden-field]").forEach((editor) => {
    const hidden = document.getElementById(editor.dataset.hiddenField)
    if (hidden) hidden.value = editor.value
  })
})
