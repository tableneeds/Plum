# Blueprint fields

Plum stores a content type blueprint as JSON with a `fields` array. Field
handles are stable template and storage keys: lowercase letters, numbers, and
underscores, beginning with a letter.

## Shared configuration

Every data field accepts `handle`, `type`, `label`, `instructions`, `required`,
`default`, `placeholder`, and `width`. Width is a grid span from 1 through 12.
A `section` organizes the entry form but stores no value.

`condition` controls visibility using another field:

```json
{ "field": "format", "operator": "equals", "value": "feature" }
```

Operators: `equals`, `not_equals`, `contains`, `empty`, and `not_empty`.

## Type-specific configuration

| Type | Configuration | Stored value |
|---|---|---|
| `text`, `textarea`, `rich_text`, `url`, `color` | Shared options | String |
| `number` | `number_kind`, `min`, `max`, `step`, `unit` | Number |
| `boolean` | Shared options | Boolean |
| `date` | `date_mode`, `min`, `max` | ISO date/time string |
| `select`, `radio`, `button_group` | `options` | Option value |
| `checkboxes` | `options` | Option-value array |
| `taxonomy` | `taxonomy` | Entry-term associations |
| `image` | Optional `folder` | Asset ID |
| `images` | `min_items`, `max_items` | Asset-ID array |
| `relationship` | `content_type`, `multiple`, item limits | Entry ID or ID array |
| `blocks` | Optional `blocks` allowlist | Block array |
| `list` | `min_items`, `max_items`, `unique` | String array |
| `group` | Nested `fields` | Object |
| `repeater` | Nested `fields`, item limits | Object array |
| `section` | Shared presentation options | Nothing |

Options may be strings or `{ "label": "Human label", "value": "stable_value" }`
objects. Existing string options remain supported.

## Theme values

Liquid receives expanded assets and relationships. An `image` becomes an asset
object, `images` becomes an array of asset objects, and relationships become an
entry object or ordered array. Stored IDs remain internal to the editor.

## Compatibility policy

Blueprint additions are backward compatible. Plum continues to read legacy
string options and single-value relationship/image fields. Changing a field's
type or handle is a content migration and should be performed in application
code before deploying the new blueprint.
