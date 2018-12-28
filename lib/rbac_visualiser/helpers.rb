module RbacVisualiser
  module Helpers

    def banner prefix, txt
      say "#{prefix.to_s.capitalize}: #{txt}".yellow.on_blue unless test?
    end

    def info txt, colour = :light_blue
      say txt.send(colour) if @verbose && !test?
    end

    def test?
      ENV['environment'] == 'test'
    end

  end
end
