# frozen_string_literal: true

module Decidim
  module Admin
    # Controller that allows managing newsletters.
    class NewslettersController < Decidim::Admin::ApplicationController
      include Decidim::NewslettersHelper
      include Decidim::Admin::NewslettersHelper
      include Paginable
      helper_method :newsletter, :recipients_count_query, :content_block, :selected_options, :newsletter_params

      def index
        enforce_permission_to :index, :newsletter
        @newsletters = collection.order(Newsletter.arel_table[:created_at].desc)
        @newsletters = paginate(@newsletters)
      end

      def new
        enforce_permission_to :create, :newsletter
        @form = form(NewsletterForm).from_model(content_block)
      end

      def show
        enforce_permission_to(:read, :newsletter, newsletter:)
        @email = NewsletterMailer.newsletter(current_user, newsletter)
      end

      def send_to_user
        enforce_permission_to :read, :newsletter, newsletter:

        NewsletterMailer.newsletter(current_user, newsletter).deliver_later
        flash[:notice] = I18n.t("newsletters.send_to_user.sent_successfully", scope: "decidim.admin", email: current_user.email)

        redirect_back fallback_location: newsletters_path
      end

      def preview
        enforce_permission_to(:read, :newsletter, newsletter:)

        email = NewsletterMailer.newsletter(current_user, newsletter, true)
        Premailer::Rails::Hook.perform(email)
        render html: email.html_part.body.decoded.html_safe
      end

      def create
        enforce_permission_to :create, :newsletter
        @form = form(NewsletterForm).from_params(params)
        @form.images = images_block_context unless has_images_block_context?

        CreateNewsletter.call(@form, content_block) do
          on(:ok) do |newsletter|
            flash.now[:notice] = I18n.t("newsletters.create.success", scope: "decidim.admin")
            redirect_to action: :show, id: newsletter.id
          end

          on(:invalid) do |newsletter|
            @newsletter = newsletter
            flash.now[:error] = I18n.t("newsletters.create.error", scope: "decidim.admin")
            render action: :new
          end
        end
      end

      def edit
        enforce_permission_to(:update, :newsletter, newsletter:)
        @form = form(NewsletterForm).from_model(content_block)
      end

      def update
        enforce_permission_to(:update, :newsletter, newsletter:)
        @form = form(NewsletterForm).from_params(params)
        @form.images = images_block_context unless has_images_block_context?

        UpdateNewsletter.call(newsletter, @form) do
          on(:ok) do |newsletter|
            flash[:notice] = I18n.t("newsletters.update.success", scope: "decidim.admin")
            redirect_to action: :show, id: newsletter.id
          end

          on(:invalid) do |newsletter|
            @newsletter = newsletter
            flash.now[:error] = I18n.t("newsletters.update.error", scope: "decidim.admin")
            render action: :edit
          end
        end
      end

      def destroy
        enforce_permission_to(:destroy, :newsletter, newsletter:)

        DestroyNewsletter.call(newsletter, current_user) do
          on(:invalid) do
            flash.now[:error] = I18n.t("newsletters.destroy.error_already_sent", scope: "decidim.admin")
            redirect_to :back
          end

          on(:ok) do
            flash[:notice] = I18n.t("newsletters.destroy.success", scope: "decidim.admin")
            redirect_to action: :index
          end
        end
      end

      def select_recipients_to_deliver
        enforce_permission_to(:update, :newsletter, newsletter:)

        @form = if newsletter_params.present?
                  form(SelectiveNewsletterForm).from_params(newsletter_params)
                else
                  form(SelectiveNewsletterForm).from_model(newsletter)
                end
      end

      def recipients_count
        @form = form(SelectiveNewsletterForm).from_params(newsletter_params)
        render plain: recipients_count_query
      end

      def deliver
        enforce_permission_to(:update, :newsletter, newsletter:)
        @form = form(SelectiveNewsletterForm).from_params(newsletter_params)

        DeliverNewsletter.call(newsletter, @form) do
          on(:ok) do
            flash[:notice] = I18n.t("newsletters.deliver.success", scope: "decidim.admin")
            redirect_to action: :index
          end

          on(:invalid) do
            flash.now[:error] = I18n.t("newsletters.deliver.error", scope: "decidim.admin")
            render action: :select_recipients_to_deliver
          end

          on(:no_recipients) do
            flash.now[:error] = I18n.t("newsletters.send.no_recipients", scope: "decidim.admin")
            render action: :select_recipients_to_deliver
          end
        end
      end

      def confirm_recipients
        enforce_permission_to(:update, :newsletter, newsletter:)
        @form = form(SelectiveNewsletterForm).from_params(newsletter_params)
        @recipients = NewsletterRecipients.for(@form).order(:email)
        @recipients = paginate(@recipients)

        render :confirm_recipients
      end

      private

      def newsletter_params
        params.fetch(:newsletter, {}).permit(
          :send_to_all_users,
          :send_to_verified_users,
          :send_to_followers,
          :send_to_participants,
          :send_to_private_members,
          verification_types: [],
          participatory_space_types: {
            assemblies: [:manifest_name, { ids: [] }],
            conferences: [:manifest_name, { ids: [] }],
            initiatives: [:manifest_name, { ids: [] }],
            participatory_processes: [:manifest_name, { ids: [] }]
          }
        )
      end

      def selected_options(key)
        @selected_options ||= {}
        @selected_options[key] ||= extract_selected_ids(params[:newsletter], key)
      end

      def extract_selected_ids(newsletter_params, key)
        return {} unless newsletter_params.present? && newsletter_params[key].present?

        if newsletter_params[key].is_a?(Array)
          { key => newsletter_params[key].map(&:to_s) }
        else
          (newsletter_params[key] || {}).transform_values { |space| space["ids"] || [] }
        end
      end

      def collection
        @collection ||= Newsletter.where(organization: current_organization)
      end

      def newsletter
        @newsletter ||= collection.find_by(id: params[:id])
      end

      def recipients_count_query
        @form ||= form(SelectiveNewsletterForm).instance
        NewsletterRecipients.for(@form).size
      end

      def content_block
        @content_block ||= content_block_for_newsletter || content_block_from_manifest
      end

      def content_block_from_manifest
        Decidim::ContentBlock.new(
          organization: current_organization,
          scope_name: :newsletter_template,
          manifest_name: params[:newsletter_template_id]
        )
      end

      def content_block_for_newsletter
        return nil unless @newsletter

        @content_block_for_newsletter ||= @newsletter.template
      end

      def images_block_context
        form(NewsletterForm).from_model(content_block).images
      end

      def has_images_block_context?
        @form.images && @form.valid?
      end
    end
  end
end
