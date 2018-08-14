require "cltk/scanner"
require "./type"

module GraphQL
  module Language
    #
    # A Lexer for GraphQL Documents
    #
    class Lexer < CLTK::Scanner
      extend CLTK::Scanner::LexerCompatibility

      @@split_lines = false

      # set a delimiter to split the string
      # for faster lexing. defaults to "\n"
      # self.pre_delimiter = "\n"

      # ignore newlines, commas and comments
      rule(/[\n\r]|[, \t]+/)
      rule(/#[^\n\r]*([\n\r][\n\r \t]*#[^\n\r]*)*/) do |comment|
        { :COMMENT, parse_comment(comment) }
      end
      rule(":") { {:COLON} }
      rule("on") { {:ON} }
      rule("fragment") { {:FRAGMENT} }
      rule("true") { {:TRUE} }
      rule("false") { {:FALSE} }
      rule("null") { {:NULL} }
      rule("query") { {:QUERY} }
      rule("mutation") { {:MUTATION} }
      rule("subscription") { {:SUBSCRIPTION} }
      rule("schema") { {:SCHEMA} }
      rule("scalar") { {:SCALAR} }
      rule("type") { {:TYPE} }
      rule("implements") { {:IMPLEMENTS} }
      rule("interface") { {:INTERFACE} }
      rule("union") { {:UNION} }
      rule("enum") { {:ENUM} }
      rule("input") { {:INPUT} }
      rule("directive") { {:DIRECTIVE} }
      rule("{") { {:LCURLY} }
      rule("}") { {:RCURLY} }
      rule("(") { {:LPAREN} }
      rule(")") { {:RPAREN} }
      rule("[") { {:LBRACKET} }
      rule("]") { {:RBRACKET} }
      rule(":") { {:COLON} }
      rule("$") { {:VAR_SIGN} }
      rule("@") { {:DIR_SIGN} }
      rule("...") { {:ELLIPSIS} }
      rule("=") { {:EQUALS} }
      rule("!") { {:BANG} }
      rule("|") { {:PIPE} }

      rule("\"") { push_state :string }

      rule(/([^\"]|\\\")*/, :string) do |t|
        escaped = replace_escaped_characters_in_place(t)
        if escaped !~ VALID_STRING
          {:BAD_UNICODE_ESCAPE, escaped}
        else
          {:STRING, escaped}
        end
      end

      rule("\"", :string) { pop_state }

      rule(/\-?(0|[1-9][0-9]*)(\.[0-9]+)?((e|E)?(\+|\-)?[0-9]+)?/) do |t|
        if t.includes?(".") || t.includes?("e") || t.includes?("E")
          {:FLOAT, t}
        else
          {:INT, t}
        end
      end

      rule(/[_A-Za-z][_0-9A-Za-z]*/) do |t|
        escaped = replace_escaped_characters_in_place(t)
        {:IDENTIFIER, escaped}
      end

      def self.parse_comment(raw)
        comment = raw.lines.reduce("") do |c, line|
          clean = line.lstrip(" \t").lstrip("#").rstrip
          c + ( clean.empty? ? "\n" : clean )
        end.lstrip
      end

      ESCAPES         = /\\["\\\/bfnrt]/
      ESCAPES_REPLACE = {
        %{\\"} => '"',
        "\\\\" => "\\",
        "\\/"  => '/',
        "\\b"  => "\b",
        "\\f"  => "\f",
        "\\n"  => "\n",
        "\\r"  => "\r",
        "\\t"  => "\t",
      }

      UTF_8         = /\\u[\dAa-f]{4}/i
      UTF_8_REPLACE = ->(m : String) { [m[-4..-1].to_i(16)] }

      VALID_STRING = /\A(?:[^\\]|#{ESCAPES}|#{UTF_8})*\z/

      def self.replace_escaped_characters_in_place(raw_string)
        raw_string.gsub(ESCAPES, ESCAPES_REPLACE).gsub(UTF_8, &UTF_8_REPLACE)
      end
    end
  end
end
