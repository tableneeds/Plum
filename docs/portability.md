# Site export, import, backup, and restore

Plum 0.3 archives are versioned ZIP files containing a JSON manifest and the
original bytes of every attached asset. The manifest carries schemas, entries,
relationships, translations, taxonomies, navigation, globals, forms, fieldsets,
settings, revisions, and submissions. Import remaps database identifiers so an
archive can be restored into a different database without collisions.

## Export and import

```sh
bin/rails plum:site:export ARCHIVE=/safe/location/site.plum.zip SITE_ID=1
bin/rails plum:site:import ARCHIVE=/safe/location/site.plum.zip NAME="Imported site" DOMAIN=example.com
```

`SITE_ID` is optional when exporting and defaults to the first site. `NAME` and
`DOMAIN` are optional import overrides. Import always creates a new site; it
never overwrites an existing site.

## Backup and restore

```sh
bin/rails plum:backup:create SITE_ID=1 DIRECTORY=/var/backups/plum
bin/rails plum:backup:restore ARCHIVE=/var/backups/plum/plum-site-1-TIMESTAMP.plum.zip
```

The backup task writes a timestamped archive. Restore uses the same safe,
new-site import path. Assets are checked against their recorded byte size and
checksum before the database transaction commits. Missing, corrupt, or
unsupported archives fail without leaving a partially imported site.

Backups must be copied off the application host and tested regularly. An archive
does not include application code, environment secrets, users, or the host
database outside the selected Plum site.

## Archive compatibility

The manifest currently uses format version `1`. Plum rejects archive versions
it does not understand instead of guessing. Future format changes will either
remain readable or ship an explicit migration path.
