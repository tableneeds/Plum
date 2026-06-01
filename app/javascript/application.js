// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
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
