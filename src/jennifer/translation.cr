module Jennifer
  module Translation
    # NOTE: temporary workarond for native I18n::Backend::Yaml until it suppurts
    # parsing locale from file first key
    class MultifileYAML < ::I18n::Backend::Yaml
      def load(path)
        files = Dir.glob(path + "/*.yml")

        files.each do |file|
          lang = File.basename(file, ".yml")
          lang_data = load_file(file)
          next if lang_data.raw.nil?

          lang_data.each do |lang, data|
            next if data.raw.nil?
            
            lang = lang.to_s
            @translations[lang] ||= {} of String => YAML::Type
            @translations[lang].merge!(self.class.normalize(data.as_h))
            @available_locales << lang unless @available_locales.includes?(lang)
          end
        end
      end
    end
  end
end
