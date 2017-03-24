require_dependency 'carto_gears_api/users/user'
require_dependency 'carto_gears_api/organizations/organization'
require_dependency 'carto_gears_api/errors'

module CartoGearsApi
  module Users
    class UsersService
      # Returns the logged user at the request.
      #
      # @param request [ActionDispatch::Request] CARTO request, as received in any controller.
      # @return [User] the user.
      def logged_user(request)
        user(request.env['warden'].user(CartoDB.extract_subdomain(request)))
      end

      # Converts an user to a viewer, without editing rights.
      # It also sets all quotas to 0
      #
      # @param user_id [UUID] the user id
      # @raise [Errors::RecordNotFound] if the user could not be found in the database
      # @raise [Errors::ValidationFailed] if the validation failed
      def make_viewer(user_id)
        user = find_user(user_id)

        user.viewer = true
        raise CartoGearsApi::Errors::ValidationFailed.new(user.errors) unless user.save
      end

      # Converts an user to a builder, with full editing rights.
      #
      # @param user_id [UUID] the user id
      # @param quota_in_bytes [Integer] quota for the user. It defaults to the organization default quota
      # @raise [Errors::RecordNotFound] if the user could not be found in the database
      # @raise [Errors::ValidationFailed] if the validation failed
      def make_builder(user_id, quota_in_bytes: nil)
        user = find_user(user_id)

        user.viewer = false
        user.quota_in_bytes = quota_in_bytes || user.organization.default_quota_in_bytes
        raise CartoGearsApi::Errors::ValidationFailed.new(user.errors) unless user.save
      end

      private

      def user(user)
        CartoGearsApi::Users::User.with(
          id: user.id,
          username: user.username,
          email: user.email,
          organization: user.organization ? organization(user.organization) : nil,
          feature_flags: user.feature_flags,
          can_change_email: user.can_change_email?,
          quota_in_bytes: user.quota_in_bytes,
          viewer: user.viewer
        )
      end

      def organization(organization)
        CartoGearsApi::Organizations::Organization.with(name: organization.name)
      end

      def find_user(user_id)
        user = ::User.find(id: user_id)
        raise CartoGearsApi::Errors::RecordNotFound.new('User', user_id) unless user
        user
      end
    end
  end
end
