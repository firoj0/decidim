# frozen_string_literal: true

require "spec_helper"
require "decidim/core/test/shared_examples/softdeleteable_components_examples"

module Decidim
  module Conferences
    module Admin
      describe ComponentsController do
        routes { Decidim::Conferences::AdminEngine.routes }

        let(:organization) { create(:organization) }
        let(:current_user) { create(:user, :confirmed, :admin, organization:) }
        let!(:conference) do
          create(
            :conference,
            :published,
            organization:
          )
        end
        let(:component) do
          create(
            :component,
            manifest_name: :dummy,
            participatory_space: conference
          )
        end

        let(:space) { conference }

        before do
          request.env["decidim.current_organization"] = organization
          request.env["decidim.current_conference"] = conference
          sign_in current_user
        end

        it_behaves_like "a reorder components controller", slug_attribute: :conference_slug
        it_behaves_like "a components controller to hide", slug_attribute: :conference_slug

        describe "PATCH update" do
          let(:component_params) do
            {
              name_en: "Dummy component",
              settings: {
                comments_enabled: true,
                dummy_global_translatable_text_en: "Dummy text"
              },
              default_step_settings: {
                comments_blocked: true,
                dummy_step_translatable_text_en: "Dummy text"
              }
            }
          end

          it "publishes the default step settings change" do
            expect(Decidim::SettingsChange).to receive(:publish).with(
              component,
              hash_including("comments_blocked" => false),
              hash_including("comments_blocked" => true)
            )

            patch :update, params: { conference_slug: conference.slug, id: component.id, component: component_params }

            expect(response).to redirect_to components_path
          end
        end

        it_behaves_like "a soft-deletable component",
                        component_name: :component,
                        space_name: :conference,
                        component_path: :components_path,
                        trash_path: :manage_trash_components_path
      end
    end
  end
end
