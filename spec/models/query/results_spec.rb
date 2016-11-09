#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe ::Query::Results, type: :model do
  let(:query) { FactoryGirl.build :query }
  let(:query_results) do
    ::Query::Results.new query, include: [:assigned_to,
                                          :type,
                                          :priority,
                                          :category,
                                          :fixed_version],
                                order: 'work_packages.root_id DESC, work_packages.lft ASC'
  end
  let(:project_1) { FactoryGirl.create :project }
  let(:role_pm) do
    FactoryGirl.create(:role,
                       permissions: [
                         :view_work_packages,
                         :edit_work_packages,
                         :create_work_packages,
                         :delete_work_packages
                       ])
  end
  let(:role_dev) do
    FactoryGirl.create(:role,
                       permissions: [:view_work_packages])
  end
  let(:user_1) do
    FactoryGirl.create(:user,
                       firstname: 'user',
                       lastname: '1',
                       member_in_project: project_1,
                       member_through_role: [role_dev, role_pm])
  end
  let(:wp_p1) do
    (1..3).map do
      FactoryGirl.create(:work_package,
                         project: project_1,
                         assigned_to_id: user_1.id)
    end
  end

  describe '#work_package_count_by_group' do
    context 'when grouping by responsible' do
      before do query.group_by = 'responsible' end

      it 'should produce a valid SQL statement' do
        expect { query_results.work_package_count_by_group }.not_to raise_error
      end
    end
  end

  describe '#work_packages' do
    let!(:project_1) { FactoryGirl.create :project }
    let!(:project_2) { FactoryGirl.create :project }
    let!(:member) {
      FactoryGirl.create(:member,
                         project: project_2,
                         principal: user_1,
                         roles: [role_pm])
    }
    let!(:user_2) {
      FactoryGirl.create(:user,
                         firstname: 'user',
                         lastname: '2',
                         member_in_project: project_2,
                         member_through_role: role_dev)
    }

    let!(:wp_p2) {
      FactoryGirl.create(:work_package,
                         project: project_2,
                         assigned_to_id: user_2.id)
    }
    let!(:wp2_p2) {
      FactoryGirl.create(:work_package,
                         project: project_2,
                         assigned_to_id: user_1.id)
    }

    before do
      wp_p1
    end

    context 'when filtering for assigned_to_role' do
      before do
        allow(User).to receive(:current).and_return(user_2)
        allow(project_2.descendants).to receive(:active).and_return([])

        query.add_filter('assigned_to_role', '=', ["#{role_dev.id}"])
      end

      context 'when a project is set' do
        before do
          allow(query).to receive(:project).and_return(project_2)
          allow(query).to receive(:project_id).and_return(project_2.id)
        end

        it 'should display only wp for selected project and selected role' do
          expect(query_results.work_packages).to match_array([wp_p2])
        end
      end

      context 'when no project is set' do
        before do
          allow(query).to receive(:project_id).and_return(false)
          allow(query).to receive(:project).and_return(false)
        end

        it 'should display all wp from projects where User.current has access' do
          expect(query_results.work_packages).to match_array([wp_p2, wp2_p2])
        end
      end
    end

    # this tests some unfortunate combination of filters where wrong
    # sql statements where produced.
    context 'with a custom field being returned and paginating' do
      let!(:custom_field) { FactoryGirl.create(:work_package_custom_field, is_for_all: true) }

      before do
        allow(User).to receive(:current).and_return(user_2)
        allow(query).to receive(:project).and_return(project_2)
        allow(query).to receive(:project_id).and_return(project_2.id)
      end

      context 'when grouping by assignees' do
        before do
          query.column_names = [:assigned_to, :"cf_#{custom_field.id}"]
          query.group_by = 'assigned_to'
        end

        it 'returns all work packages of project 2' do
          work_packages = query.results(include: [:assigned_to, { custom_values: :custom_field }],
                                        order: 'work_packages.root_id, work_packages.lft')
                          .work_packages
                          .page(1)
                          .per_page(10)

          expect(work_packages).to match_array([wp_p2, wp2_p2])
        end
      end

      context 'when grouping by responsibles' do
        before do
          query.column_names = [:responsible, :"cf_#{custom_field.id}"]
          query.group_by = 'responsible'
        end

        it 'returns all work packages of project 2' do
          work_packages = query.results(include: [:responsible, { custom_values: :custom_field }],
                                        order: 'work_packages.root_id, work_packages.lft')
                          .work_packages
                          .page(1)
                          .per_page(10)

          expect(work_packages).to match_array([wp_p2, wp2_p2])
        end
      end
    end

    context 'when grouping by responsible' do
      before do
        allow(User).to receive(:current).and_return(user_1)

        wp_p1[0].update_attribute(:responsible, user_1)
        wp_p1[1].update_attribute(:responsible, user_2)

        query.project = project_1
        query.group_by = 'responsible'
      end

      it 'outputs the work package count in the schema { <User> => count }' do
        expect(query_results.work_package_count_by_group).to eql(user_1 => 1, user_2 => 1, nil => 1)
      end
    end
  end

  # Introduced to ensure being able to group by custom fields
  # when running on a MySQL server.
  # When upgrading to rails 5, the sql_mode passed on with the connection
  # does include the "only_full_group_by" flag by default which causes our queries to become
  # invalid because (mysql error):
  # "SELECT list is not in GROUP BY clause and contains nonaggregated column
  # 'config_myproject_test.work_packages.id' which is not functionally
  # dependent on columns in GROUP BY clause"
  context 'when grouping by custom field' do
    let!(:custom_field) do
      FactoryGirl.create(:int_wp_custom_field, is_for_all: true, is_filter: true)
    end

    before do
      allow(User).to receive(:current).and_return(user_1)

      wp_p1[0].type.custom_fields << custom_field
      project_1.work_package_custom_fields << custom_field

      wp_p1[0].update_attribute(:"custom_field_#{custom_field.id}", 42)
      wp_p1[0].save
      wp_p1[1].update_attribute(:"custom_field_#{custom_field.id}", 42)
      wp_p1[1].save

      query.project = project_1
      query.group_by = "cf_#{custom_field.id}"
    end

    describe '#work_package_count_by_group' do
      it 'returns a hash of counts by value' do
        expect(query.results.work_package_count_by_group).to eql(42 => 2, nil => 1)
      end
    end
  end
end
