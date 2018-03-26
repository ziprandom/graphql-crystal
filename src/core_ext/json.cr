module JSON
  {% if @type.has_constant? "Type" %}
  NEW_JSON_ANY_TYPE = false
  {% else %}
  NEW_JSON_ANY_TYPE = true
  {% end %}
end
