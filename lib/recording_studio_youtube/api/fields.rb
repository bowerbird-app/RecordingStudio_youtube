# frozen_string_literal: true

module RecordingStudio
  module YouTube
    module Api
      module Fields
        module_function

        def string(description, required: false)
          { type: :string, required: required, description: description }
        end

        def integer(description)
          { type: :integer, required: false, description: description }
        end

        def id(resource)
          string("#{resource} id.", required: true)
        end

        def page_token
          string("Token from a previous page. Omit it for the first page.")
        end

        def max_results(default:, max:)
          integer("Page size from 0 to #{max}. The default is #{default}.")
        end

        def comment_max_results
          integer("Page size from 1 to 100. The default is 20.")
        end

        def query_contract(fields)
          { reject_unknown: false, fields: fields }
        end

        def query_parameter(name, description, required: false, type: "string", location: "query")
          {
            name: name.to_s,
            in: location,
            required: required,
            description: description,
            schema: { type: type }
          }
        end
      end
    end
  end
end
