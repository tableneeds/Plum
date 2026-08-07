# Extending Plum

Plum exposes Rails-native extension points for host applications and gems. An
initializer can register a field type with its control-panel partial and value
pipeline:

```ruby
Plum.register_field_type(
  handle: :postal_code,
  label: "Postal Code",
  partial: "my_engine/fields/postal_code",
  normalizer: ->(value:, **) { value.to_s.upcase.delete(" ") },
  validator: ->(value:, **) { "is invalid" unless value.to_s.match?(/\A\d{5}\z/) },
  expander: ->(value:, **) { { "value" => value, "country" => "US" } }
)
```

The partial receives `field`, `field_handle`, `field_id`, `field_value`, and
`entry`. Its submitted input must use `entry[data][HANDLE]`.

The normalizer runs before persistence and receives `value`, `field`, `entry`,
and `controller`. The validator runs on the normalized entry value and returns
one message, multiple messages, or `nil`. The expander controls the value sent
to Liquid and the JSON content API and receives `value`, `field`, `site`, and
`expander`.

Registration rejects invalid or duplicate handles. Custom types automatically
appear in the visual blueprint type picker and participate in normal required,
default, instruction, conditional-visibility, and field-width behavior.

Plum also supports registered content sources and host-owned authorization; see
the corresponding README sections for those APIs.
