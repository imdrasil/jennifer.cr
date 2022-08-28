require "crypto/bcrypt/password"

module Jennifer
  module Model
    module Authentication
      # Password virtual attribute type definition.
      Password = {
        type:    String?,
        virtual: true,
        setter:  false,
      }

      {% Macros::TYPES << "Password" %}

      PASSWORD_RANGE = Crypto::Bcrypt::PASSWORD_RANGE.min...Crypto::Bcrypt::PASSWORD_RANGE.max

      # Adds methods to set and authenticate against a Crypto::Bcrypt password.
      # - `password` - password field name (default is `"password"`);
      # - `password_hash` - password digest attribute name (default is `"password_digest"`);
      # - `skip_validation` - whether validations shouldn't be generated (default is `false`).
      macro with_authentication(password = "password", password_hash = "password_digest", skip_validation = false)
        {% if !skip_validation %}
          validates_length :{{password.id}}, in: PASSWORD_RANGE, allow_blank: true
          validates_confirmation :{{password.id}}
          validates_with_method :validate_{{password.id}}_presence
        {% end %}

        after_initialize :initialize_{{password_hash.id}}

        def authenticate(given_password)
          self if Crypto::Bcrypt::Password.new({{password_hash.id}}).verify given_password
        end

        def {{password.id}}=(unencrypted_password : String)
          @{{password.id}} = unencrypted_password
          if unencrypted_password.empty? || !PASSWORD_RANGE.includes?(unencrypted_password.size)
            self.{{password.id}} = nil
          else
            self.{{password_hash.id}} = Crypto::Bcrypt::Password.create(
              unencrypted_password,
              cost: self.class.{{password_hash.id}}_cost
            ).to_s
            unencrypted_password
          end
        end

        def {{password.id}}=(unencrypted_password : Nil)
          self.{{password_hash.id}} = ""
        end

        def self.{{password_hash.id}}_cost
          Crypto::Bcrypt::DEFAULT_COST
        end

        private def validate_{{password.id}}_presence
          errors.add(:{{password.id}}, :blank) if {{password_hash.id}}.blank?
        end

        private def initialize_{{password_hash.id}}
          return unless new_record? && {{password.id}}.present?

          self.{{password.id}}= {{password.id}}
          true
        end
      end
    end
  end
end
