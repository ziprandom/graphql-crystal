module JSON
  {% if Crystal::VERSION.gsub(/[^0-9]/, "").to_i > 242 %}
  NEW_JSON_ANY_TYPE = true
  {% else %}
  NEW_JSON_ANY_TYPE = false
  {% end %}
end
