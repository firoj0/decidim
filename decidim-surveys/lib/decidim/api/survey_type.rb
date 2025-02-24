# frozen_string_literal: true

module Decidim
  module Surveys
    class SurveyType < Decidim::Api::Types::BaseObject
      description "A survey"

      field :id, GraphQL::Types::ID, "The internal ID for this survey", null: false
      field :created_at, Decidim::Core::DateTimeType, "The time this survey was created", null: true
      field :updated_at, Decidim::Core::DateTimeType, "The time this survey was updated", null: true
      field :questionnaire, Decidim::Forms::QuestionnaireType, "The questionnaire for this survey", null: true

      def self.authorized?(object, context)
        context[:survey] = object
        context[:current_settings] = object.component.current_settings

        super
      rescue Decidim::PermissionAction::PermissionNotSetError
        false
      end
    end
  end
end
