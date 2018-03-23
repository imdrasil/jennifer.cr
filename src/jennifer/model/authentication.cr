require "crypto/bcrypt/password"

module Jennifer
  module Model
    module Authentication
      # Password virtual attribute type definition.
      Password = {
        type: String?,
        virtual: true,
        setter: false
      }

      {% Macros::TYPES << "Password" %}

      # Adds methods to set and authenticate against a Crypto::Bcrypt password.
      # - `password` - password field name (default is `"password"`);
      # - `password_hash` - password digest attribute name (default is `"password_digest"`).
      macro with_authentication(password = "password", password_hash = "password_digest")
        validates_length :{{password.id}}, maximum: Crypto::Bcrypt::PASSWORD_RANGE.max, allow_blank: true
        validates_confirmation :{{password.id}}
        validates_with_method :validate_{{password.id}}_presence

        def authenticate(given_password)
          self if Crypto::Bcrypt::Password.new({{password_hash.id}}) == given_password
        end

        def {{password.id}}=(unencrypted_password)
          @{{password.id}} = unencrypted_password
          if unencrypted_password.nil? || unencrypted_password.empty? || !Crypto::Bcrypt::PASSWORD_RANGE.includes?(unencrypted_password.not_nil!.size)
            self.{{password_hash.id}} = ""
          else
            self.{{password_hash.id}} = Crypto::Bcrypt::Password.create(
              unencrypted_password.not_nil!,
              cost: self.class.{{password_hash.id}}_cost
            ).to_s
          end
        end

        def self.{{password_hash.id}}_cost
          Crypto::Bcrypt::DEFAULT_COST
        end

        private def validate_{{password.id}}_presence
          errors.add(:{{password.id}}, self.class.human_error({{password}}, :blank)) if {{password_hash.id}}.blank?
        end
      end
    end
  end
end
