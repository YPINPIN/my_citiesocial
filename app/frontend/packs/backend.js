import Rails from "@rails/ujs"
import Turbolinks from "turbolinks"
import * as ActiveStorage from "@rails/activestorage"

Rails.start()
Turbolinks.start()
ActiveStorage.start()

import "controllers"

import "scripts/shared"
import "scripts/backend"

import "styles/shared"
import "styles/backend"
