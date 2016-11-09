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

module API
  module V3
    module WorkPackages
      module AvailableRelationCandidatesHelper
        include API::V3::Utilities::PathHelper

        ##
        # Queries the compatible work package's to the given one as much as possible through the
        # database.
        #
        # @param query [String] The ID or part of a subject to filter by
        # @param from [WorkPackage] The work package in the `from` position of a relation.
        # @param limit [Integer] Maximum number of results to retrieve.
        def work_package_query(query, from, limit)
          wps = WorkPackage.visible
                           .where("work_packages.id = ? OR work_packages.subject LIKE ?",
                                  query.to_i, "%#{query}%")
                           .where('work_packages.id != ?', from.id) # can't relate to itself
                           .references(:work_packages)
                           .limit(limit)

          if Setting.cross_project_work_package_relations?
            wps
          else
            wps.where(project_id: from.project_id) # has to be same project
          end
        end

        def filter_work_packages(work_packages, from, type)
          work_packages.reject { |to| illegal_relation? type, from, to }
        end

        def illegal_relation?(type, from, to)
          rel = Relation.new(relation_type: type, from: from, to: to)

          rel.shared_hierarchy? || rel.circular_dependency?
        end
      end
    end
  end
end
