pin "plum/application", to: "plum/application.js"
pin_all_from Plum::Engine.root.join("app/javascript/controllers/plum"), under: "controllers/plum", to: "plum"
pin "lexxy", to: "lexxy.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
