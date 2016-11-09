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

describe Queries::WorkPackages::Filter::StatusFilter, type: :model do
  let(:status) { FactoryGirl.build_stubbed(:status) }

  it_behaves_like 'basic query filter' do
    let(:order) { 1 }
    let(:type) { :list_status }
    let(:class_key) { :status_id }

    describe '#available?' do
      it 'is true if any status exists' do
        allow(Status)
          .to receive(:exists?)
          .and_return true

        expect(instance).to be_available
      end

      it 'is false if no status exists' do
        allow(Status)
          .to receive(:exists?)
          .and_return false

        expect(instance).to_not be_available
      end
    end

    describe '#allowed_values' do
      before do
        allow(Status)
          .to receive(:all)
          .and_return [status]
      end

      it 'is an array of status values' do
        expect(instance.allowed_values)
          .to match_array [[status.name, status.id.to_s]]
      end
    end
  end
end
