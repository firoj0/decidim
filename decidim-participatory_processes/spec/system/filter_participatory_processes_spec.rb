# frozen_string_literal: true

require "spec_helper"

describe "Filter Participatory Processes" do
  let(:organization) { create(:organization) }

  before do
    switch_to_host(organization.host)
  end

  shared_examples "listing all processes" do
    it "lists all processes ordered by start_date (closest to current_date)" do
      within "#processes-grid h2" do
        expect(page).to have_content("6 processes")
      end

      within "#processes-grid" do
        expect(titles[0].text).to eq("Started today")
        expect(titles[1].text).to eq("Started 1 day ago")
        expect(titles[2].text).to eq("Starts 1 week from now")
        expect(titles[3].text).to eq("Started 2 weeks ago")
        expect(titles[4].text).to eq("Started 3 weeks ago")
        expect(titles[5].text).to eq("Starts 1 year from now")
      end
    end
  end

  context "when filtering processes by date" do
    let!(:active_process) { create(:participatory_process, title: { en: "Started today" }, start_date: Date.current, organization:) }
    let!(:active_process2) { create(:participatory_process, title: { en: "Started 1 day ago" }, start_date: 1.day.ago, organization:) }
    let!(:past_process) { create(:participatory_process, :past, title: { en: "Ended 1 week ago" }, organization:) }
    let!(:past_process2) { create(:participatory_process, :past, title: { en: "Ended 1 month ago" }, end_date: 1.month.ago, organization:) }
    let!(:upcoming_process) { create(:participatory_process, :upcoming, title: { en: "Starts 1 week from now" }, organization:) }
    let!(:upcoming_process2) { create(:participatory_process, :upcoming, title: { en: "Starts 1 year from now" }, start_date: 1.year.from_now, organization:) }
    let(:titles) { page.all(".card__grid-text h3") }

    before do
      visit decidim_participatory_processes.participatory_processes_path
    end

    context "and choosing 'active' processes" do
      it "lists the active processes ordered by start_date (descendingly)" do
        within "#processes-grid h2" do
          expect(page).to have_content("2 active processes")
        end

        within "#processes-grid" do
          expect(titles.first.text).to eq("Started today")
          expect(titles.last.text).to eq("Started 1 day ago")
        end
      end
    end

    context "and choosing 'past' processes" do
      before do
        within "#panel-dropdown-menu-date" do
          click_filter_item "Past"
        end
      end

      it "lists the past processes ordered by end_date (descendingly)" do
        within "#processes-grid h2" do
          expect(page).to have_content("2 past processes")
        end

        within "#processes-grid" do
          expect(titles.first.text).to eq("Ended 1 week ago")
          expect(titles.last.text).to eq("Ended 1 month ago")
        end
      end
    end

    context "and choosing 'upcoming' processes" do
      before do
        within "#panel-dropdown-menu-date" do
          click_filter_item "Upcoming"
        end
        sleep 2
      end

      it "lists the upcoming processes ordered by start_date (ascendingly)" do
        within "#processes-grid h2" do
          expect(page).to have_content("2")
        end

        within "#processes-grid" do
          expect(titles.first.text).to eq("Starts 1 week from now")
          expect(titles.last.text).to eq("Starts 1 year from now")
        end
      end
    end

    context "and choosing 'all' processes" do
      let(:time_zone) { Time.zone } # UTC

      before do
        past_process.update(title: { en: "Started 2 weeks ago" })
        past_process2.update(title: { en: "Started 3 weeks ago" }, start_date: 3.weeks.ago)
        allow(Time).to receive(:zone).and_return(time_zone)
        within "#panel-dropdown-menu-date" do
          click_filter_item "All"
        end
      end

      it_behaves_like "listing all processes"

      context "when the configured time_zone is not UTC" do
        let(:time_zone) { ActiveSupport::TimeZone.new("Madrid") }

        it_behaves_like "listing all processes"
      end
    end
  end

  context "when filtering parent participatory processes by taxonomies" do
    let!(:taxonomy) { create(:taxonomy, :with_parent, organization:) }
    let!(:process_with_taxonomy) { create(:participatory_process, taxonomies: [taxonomy], organization:) }
    let!(:process_without_taxonomy) { create(:participatory_process, organization:) }

    context "and choosing a taxonomy" do
      before do
        visit decidim_participatory_processes.participatory_processes_path(filter: { with_any_taxonomies: { taxonomy.parent_id => [taxonomy.id] } })
      end

      it "lists all processes belonging to that taxonomy" do
        within "#processes-grid" do
          expect(page).to have_content(translated(process_with_taxonomy.title))
          expect(page).to have_no_content(translated(process_without_taxonomy.title))
        end
      end
    end
  end

  context "when filtering processes by type" do
    context "when there are no participatory processes types" do
      let!(:processes) { create_list(:participatory_process, 3, :active, organization:) }

      context "when visiting processes index" do
        before do
          visit decidim_participatory_processes.participatory_processes_path
        end

        it "does not show the participatory process types filter" do
          expect(page).to have_no_css("#process-type-filter")
        end
      end
    end

    context "when there are participatory processes types" do
      let!(:process_type) { create(:participatory_process_type, :with_active_participatory_processes, organization:, title: { en: "Awesome Type" }) }
      let!(:past_process_type) { create(:participatory_process_type, :with_past_participatory_processes, organization:, title: { en: "Old Type" }) }
      let!(:unpublished_process_type) { create(:participatory_process_type, organization:, title: { en: "Unpublished Type" }) }
      let!(:empty_process_type) { create(:participatory_process_type, organization:, title: { en: "Empty Type" }) }
      let!(:processes_group1) { create(:participatory_process_group, organization:, title: { en: "The South Group" }) }
      let!(:processes_group2) { create(:participatory_process_group, organization:, title: { en: "The North Group" }) }
      let!(:group_1_process_type) { create(:participatory_process_type, :with_active_participatory_processes, organization:, title: { en: "The East Type" }) }
      let!(:group_2_process_type) { create(:participatory_process_type, :with_active_participatory_processes, organization:, title: { en: "The West Type" }) }
      let!(:processes1) do
        create_list(
          :participatory_process,
          3,
          title: { en: "SE Rocks!" },
          start_date: 2.days.ago,
          organization:,
          participatory_process_group: processes_group1,
          participatory_process_type: group_1_process_type
        )
      end
      let!(:processes2) do
        create_list(
          :participatory_process,
          3,
          title: { en: "NW Rocks!" },
          start_date: 2.days.ago,
          organization:,
          participatory_process_group: processes_group2,
          participatory_process_type: group_2_process_type
        )
      end
      let(:unpublished_process) do
        create(
          :participatory_process,
          :active,
          :unpublished,
          title: { en: "Unpublished process" },
          participatory_process_type: unpublished_process_type
        )
      end

      context "when visiting processes index" do
        before do
          visit decidim_participatory_processes.participatory_processes_path
        end

        context "and choosing 'active' processes" do
          it "lists all active processes" do
            within "#processes-grid h2" do
              expect(page).to have_content("8 active processes")
            end
          end
        end

        context "and choosing 'past' processes" do
          before do
            within "#panel-dropdown-menu-date" do
              click_filter_item "Past"
            end
            sleep 2
          end

          it "lists past processes" do
            within "#processes-grid h2" do
              expect(page).to have_content("2 past processes")
            end
          end
        end

        context "and filtering by a process type" do
          before do
            within "#panel-dropdown-menu-type" do
              click_filter_item "The West Type"
            end
            sleep 2
          end

          it "lists process type processes" do
            within "#processes-grid h2" do
              expect(page).to have_content("3 active processes")
            end

            expect(page).to have_no_content("NW Rocks!")
            expect(page).to have_no_content("SE Rocks!")
            group_1_process_type.processes.groupless.each do |group|
              expect(page).to have_no_content(translated(group.title))
            end
            group_2_process_type.processes.groupless.each do |group|
              expect(page).to have_content(translated(group.title))
            end
          end
        end

        context "and filtering by more than one process type" do
          before do
            within "#panel-dropdown-menu-type" do
              click_filter_item "The West Type"
              click_filter_item "The East Type"
            end
            sleep 2
          end

          it "lists process type processes" do
            within "#processes-grid h2" do
              expect(page).to have_content("6 active processes")
            end

            expect(page).to have_no_content("NW Rocks!")
            expect(page).to have_no_content("SE Rocks!")
            group_1_process_type.processes.groupless.each do |group|
              expect(page).to have_content(translated(group.title))
            end
            group_2_process_type.processes.groupless.each do |group|
              expect(page).to have_content(translated(group.title))
            end
          end
        end
      end
    end
  end
end
