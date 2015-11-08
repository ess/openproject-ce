// -- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
// ++

angular
  .module('openproject.inplace-edit')
  .directive('editActionsBar', editActionsBar);

function editActionsBar() {
  return {
    restrict: 'E',
    replace: true,
    templateUrl: '/components/inplace-edit/directives/edit-actions-bar/' +
      'edit-actions-bar.directive.html',

    scope: {},

    bindToController: true,
    controllerAs: 'vm',
    controller:  function ($scope, I18n, EditableFieldsState, $window) {

      angular.extend(this, {
        visible: function () {
          return EditableFieldsState.editAll.state && EditableFieldsState.editAll.allowed;
        },

        save: function () {
          EditableFieldsState.save();
        },

        cancel: function () {
          EditableFieldsState.editAll.cancel();
        },

        text: {
          save: I18n.t('js.button_save'),
          cancel: I18n.t('js.button_cancel')
        }
      });

      $scope.$on('$stateChangeStart', function (event, toState, toParams, fromState, fromParams) {
        if (EditableFieldsState.editAll.state
          && toParams.workPackageId !== fromParams.workPackageId) {

          if (!$window.confirm(I18n.t('js.text_are_you_sure'))) {
            event.preventDefault();

          } else {
            EditableFieldsState.editAll.cancel();
          }
        }
      })
    }
  };
};
