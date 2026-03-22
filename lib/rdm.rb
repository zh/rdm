# frozen_string_literal: true

require_relative "rdm/version"
require_relative "rdm/errors"
require_relative "rdm/config"
require_relative "rdm/client"
require_relative "rdm/formatter"
require_relative "rdm/commands/base"
require_relative "rdm/commands/login"
require_relative "rdm/commands/status"
require_relative "rdm/commands/logout"
require_relative "rdm/commands/open"
require_relative "rdm/commands/projects"
require_relative "rdm/commands/issues"
require_relative "rdm/commands/time_entries"
require_relative "rdm/commands/users"
require_relative "rdm/commands/versions"
require_relative "rdm/commands/memberships"
require_relative "rdm/commands/groups"
require_relative "rdm/commands/queries"
require_relative "rdm/commands/custom_fields"
require_relative "rdm/commands/reference"
require_relative "rdm/cli"

module Rdm
end
