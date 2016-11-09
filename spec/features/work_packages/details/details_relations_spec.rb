require 'spec_helper'

describe 'Work package relations tab', js: true, selenium: true do
  include_context 'typeahead helpers'

  let(:user) { FactoryGirl.create :admin }

  let(:project) { FactoryGirl.create :project }
  let(:work_package) { FactoryGirl.create(:work_package, project: project) }
  let(:work_packages_page) { ::Pages::SplitWorkPackage.new(work_package) }

  let(:visit) { true }

  before do
    login_as user

    if visit
      visit_relations
    end
  end

  def visit_relations
    work_packages_page.visit_tab!('relations')
    work_packages_page.expect_subject
    loading_indicator_saveguard
  end

  def add_hierarchy(container, query, expected_text)
    # Locate the create row container
    container = find(container)

    # Enter the query and select the child
    typeahead = container.find(".wp-relations--autocomplete")
    select_typeahead(typeahead, query: query, select_text: expected_text)

    container.find('.wp-create-relation--save').click

    expect(page).to have_selector('.wp-relations-hierarchy-subject',
                                  text: expected_text,
                                  wait: 10)
  end

  def add_relation(relation_type, wp)
    # Open create form
    find('#relation--add-relation').click

    # Select relation type
    container = find('.wp-relations-create--form', wait: 10)

    # Labels to expect
    relation_label = I18n.t('js.relation_labels.' + relation_type)

    select relation_label, from: 'relation-type--select'

    # Enter the query and select the child
    typeahead = container.find(".wp-relations--autocomplete")
    select_typeahead(typeahead, query: wp.subject, select_text: wp.subject)

    container.find('.wp-create-relation--save').click

    expect(page).to have_selector('.relation-group--header',
                                  text: relation_label.upcase,
                                  wait: 10)

    expect(page).to have_selector('.relation-row--type', text: wp.type.name)

    expect(page).to have_selector('.wp-relations--subject-field', text: wp.subject)

    ## Test if relation exist
    work_package.reload
    relation = work_package.relations.first
    expect(relation.relation_type).to eq('precedes')
    expect(relation.from_id).to eq(relatable.id)
    expect(relation.to_id).to eq(work_package.id)
  end

  def remove_hierarchy(selector, removed_text)
    expect(page).to have_selector(selector, text: removed_text)
    container = find(selector)
    container.hover

    container.find('.wp-relation--remove').click
    expect(page).to have_no_selector(selector, text: removed_text, wait: 10)
  end

  describe 'as admin' do
     let!(:parent) { FactoryGirl.create(:work_package, project: project) }
     let!(:child) { FactoryGirl.create(:work_package, project: project) }
     let!(:child2) { FactoryGirl.create(:work_package, project: project, subject: 'Something new') }

    it 'allows to mange hierarchy' do
      # Shows link parent link
      expect(page).to have_selector('#hierarchy--add-parent')
      find('.wp-inline-create--add-link',
           text: I18n.t('js.relation_buttons.add_parent')).click

      # Add parent
      add_hierarchy('.wp-relations--parent-form', parent.id, parent.subject)

      ##
      # Add child #1
      find('.wp-inline-create--add-link',
           text: I18n.t('js.relation_buttons.add_existing_child')).click

      add_hierarchy('.wp-relations--child-form', child.id, child.subject)

      ##
      # Add child #2
      find('.wp-inline-create--add-link',
           text: I18n.t('js.relation_buttons.add_existing_child')).click

      add_hierarchy('.wp-relations--child-form', child2.subject, child2.subject)
    end
  end

  describe 'relation group-by toggler' do
    let(:project) { FactoryGirl.create :project, types: [type_1, type_2] }
    let(:type_1) { FactoryGirl.create :type }
    let(:type_2) { FactoryGirl.create :type }

    let(:to_1) { FactoryGirl.create(:work_package, type: type_1, project: project) }
    let(:to_2) { FactoryGirl.create(:work_package, type: type_2, project: project) }

    let!(:relation_1) do
      FactoryGirl.create :relation,
                         from: work_package,
                         to: to_1,
                         relation_type: :follows
    end
    let!(:relation_2) do
      FactoryGirl.create :relation,
                         from: work_package,
                         to: to_2,
                         relation_type: :relates
    end

    let(:toggle_btn_selector) { '#wp-relation-group-by-toggle' }
    let(:visit) { false }

    it 'allows to toggle how relations are grouped' do
      visit_relations

      work_packages_page.visit_tab!('relations')
      work_packages_page.expect_subject
      loading_indicator_saveguard

      # Expect to be grouped by relation type by default
      expect(page).to have_selector(toggle_btn_selector,
                                    text: 'Group by work package type', wait: 10)

      expect(page).to have_selector('.relation-group--header', text: 'FOLLOWS')
      expect(page).to have_selector('.relation-group--header', text: 'RELATED TO')

      expect(page).to have_selector('.relation-row--type', text: type_1.name)
      expect(page).to have_selector('.relation-row--type', text: type_2.name)

      find(toggle_btn_selector).click
      expect(page).to have_selector(toggle_btn_selector, text: 'Group by relation type', wait: 10)

      expect(page).to have_selector('.relation-group--header', text: type_1.name.upcase)
      expect(page).to have_selector('.relation-group--header', text: type_2.name.upcase)

      expect(page).to have_selector('.relation-row--type', text: 'Follows')
      expect(page).to have_selector('.relation-row--type', text: 'Related To')
    end
  end

  describe 'with limited permissions' do
    let(:permissions) { %i(view_work_packages) }
    let(:user_role) do
      FactoryGirl.create :role, permissions: permissions
    end

    let(:user) do
      FactoryGirl.create :user,
                         member_in_project: project,
                         member_through_role: user_role
    end

    context 'as view-only user, with parent set' do
      let(:parent) { FactoryGirl.create(:work_package, project: project) }
      let(:work_package) { FactoryGirl.create(:work_package, parent: parent, project: project) }

      it 'shows no links to create relations' do
        # No create buttons should exist
        expect(page).to have_no_selector('.wp-relations-create-button')

        # Test for add relation
        expect(page).to have_no_selector('#relation--add-relation')

        # Test for add parent
        expect(page).to have_no_selector('#hierarchy--add-parent')

        # Test for add children
        expect(page).to have_no_selector('#hierarchy--add-exisiting-child')
        expect(page).to have_no_selector('#hierarchy--add-new-child')

        # But it should show the linked parent
        expect(page).to have_selector('.wp-relations-hierarchy-subject', text: parent.subject)
      end
    end

    context 'with manage_subtasks permissions' do
      let(:permissions) { %i(view_work_packages manage_subtasks) }
      let!(:parent) { FactoryGirl.create(:work_package, project: project) }
      let!(:child) { FactoryGirl.create(:work_package, project: project) }

      it 'should be able to link parent and children' do
        # Shows link parent link
        expect(page).to have_selector('#hierarchy--add-parent')
        find('.wp-inline-create--add-link',
             text: I18n.t('js.relation_buttons.add_parent')).click

        # Add parent
        add_hierarchy('.wp-relations--parent-form', parent.id, parent.subject)

        ##
        # Add child
        find('.wp-inline-create--add-link',
             text: I18n.t('js.relation_buttons.add_existing_child')).click

        add_hierarchy('.wp-relations--child-form', child.id, child.subject)

        # Remove parent
        remove_hierarchy('.relation-row.parent', parent.subject)

        # Remove child
        remove_hierarchy('.relation-row.child', child.subject)
      end
    end

    context 'with relations permissions' do
      let(:permissions) do
        %i(view_work_packages add_work_packages manage_subtasks manage_work_package_relations)
      end

      let!(:relatable) { FactoryGirl.create(:work_package, project: project) }
      it 'should allow to manage relations' do
        add_relation('follows', relatable)

        ## Delete relation
        created_row = find(".relation-row-#{relatable.id}")

        # Hover row to expose button
        created_row.hover
        created_row.find('.relation-row--remove-btn').click

        expect(page).to have_no_selector('.relation-group--header', text: 'FOLLOWS')
        expect(page).to have_no_selector('.wp-relations--subject-field', text: relatable.subject)

        work_package.reload
        expect(work_package.relations).to be_empty
      end

      it 'should allow to move between split and full view (Regression #24194)' do
        add_relation('follows', relatable)

        # Switch to full view
        find('#work-packages-show-view-button').click

        # Expect to have row
        created_row = find(".relation-row-#{relatable.id}", wait: 10)

        created_row.hover
        created_row.find('.relation-row--remove-btn').click

        expect(page).to have_no_selector('.relation-group--header', text: 'FOLLOWS')
        expect(page).to have_no_selector('.wp-relations--subject-field', text: relatable.subject)

        # Back to split view
        find('#work-packages-details-view-button').click
        work_packages_page.expect_subject

        expect(page).to have_no_selector('.relation-group--header', text: 'FOLLOWS')
        expect(page).to have_no_selector('.wp-relations--subject-field', text: relatable.subject)
      end

      it 'should allow to change relation descriptions' do
        add_relation('follows', relatable)

        created_row = find(".relation-row-#{relatable.id}")

        ## Toggle description
        created_row.hover
        toggle_btn = created_row.find('.wp-relations--description-btn')
        toggle_btn.click

        # Open textarea
        created_row.find('.wp-relation--description-read-value.-placeholder',
                         text: I18n.t('js.placeholders.relation_description')).click

        expect(page).to have_focus_on('.wp-relation--description-textarea')
        textarea = created_row.find('.wp-relation--description-textarea')
        textarea.set 'my description!'

        # Save description
        created_row.find('.inplace-edit--control--save a').click
        created_row.find('.wp-relation--description-read-value',
                         text: 'my description!').click

        # Cancel edition
        created_row.find('.inplace-edit--control--cancel a').click
        created_row.find('.wp-relation--description-read-value',
                         text: 'my description!').click

        relation = work_package.relations.first
        relation.reload
        expect(relation.description).to eq('my description!')

        # Toggle to close
        toggle_btn.click
        expect(created_row).to have_no_selector('.wp-relation--description-read-value')
      end
    end
  end
end
